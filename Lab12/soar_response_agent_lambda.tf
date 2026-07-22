## Permissions
resource "aws_iam_policy" "soar_response_agent_policy" {
  name = "soar-response-agent-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["sns:Publish"]
        Effect   = "Allow"
        Resource = aws_sns_topic.soar_response_topic.arn
      }
    ]
  })
}
resource "aws_iam_role" "soar_response_agent_lambda_execution_role" {
  name               = "soar_response_agent_lambda_lab_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "soar_response_agent_lambda_basic" {
  role       = aws_iam_role.soar_response_agent_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "soar_response_agent_bedrock_invoke" {
  role       = aws_iam_role.soar_response_agent_lambda_execution_role.name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

resource "aws_iam_role_policy_attachment" "soar_response_agent_policy" {
  role       = aws_iam_role.soar_response_agent_lambda_execution_role.name
  policy_arn = aws_iam_policy.soar_response_agent_policy.arn
}

resource "aws_iam_role_policy_attachment" "soar_response_agent_correlation_table" {
  role       = aws_iam_role.soar_response_agent_lambda_execution_role.name
  policy_arn = aws_iam_policy.waf_correlation_findings_table.arn
}

resource "aws_iam_role_policy_attachment" "soar_response_agent_incidents_table" {
  role       = aws_iam_role.soar_response_agent_lambda_execution_role.name
  policy_arn = aws_iam_policy.security_incidents_table.arn
}

## Event Bridge 
resource "aws_cloudwatch_event_rule" "invoke_soar_lambda_rule" {
  name           = "invoke-soar-lambda-rule"
  description    = "Invoke the SOAR response agent when a new finding is put on the bus"
  event_bus_name = var.waf_correlation_bus_name
  event_pattern = jsonencode({
    "source" : [
      var.waf_correlation_event_source
    ]
  })
}

# we have to set the lambda as a target for the rule
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target
resource "aws_cloudwatch_event_target" "invoke_soar_lambda_target" {
  rule           = aws_cloudwatch_event_rule.invoke_soar_lambda_rule.name
  target_id      = "soar-response-agent-lambda"
  arn            = aws_lambda_function.soar_response_agent_lambda.arn
  event_bus_name = var.waf_correlation_bus_name
}

## to allow event bridge to invoke lamdba you need a resource policy
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_soar_lambda" {
  statement_id  = "AllowInvokeSoarLambdaFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_response_agent_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.invoke_soar_lambda_rule.arn
}



## SNS Topic
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic
resource "aws_sns_topic" "soar_response_topic" {
  name = var.soar_sns_topic_name
}

#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription
# https://oneuptime.com/blog/post/2026-02-12-create-sns-topics-with-terraform/view
# don't forget to manually confirm the subscription...may be better to have a webhook or something in discord
resource "aws_sns_topic_subscription" "soar_response_subscription" {
  topic_arn = aws_sns_topic.soar_response_topic.arn
  protocol  = "email"
  endpoint  = var.soar_sns_email_endpoint
}

## Lambda
resource "aws_cloudwatch_log_group" "soar_response_agent_lambda_logs" {
  name              = "/aws/lambda/${local.soar_response_agent_function_name}"
  retention_in_days = 3
}

data "archive_file" "soar_response_agent_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/soar_response_agent.py"
  output_path = "${path.module}/src/soar-response-agent-lambda.zip"
}

resource "aws_lambda_function" "soar_response_agent_lambda" {
  function_name = local.soar_response_agent_function_name
  role          = aws_iam_role.soar_response_agent_lambda_execution_role.arn
  filename      = data.archive_file.soar_response_agent_lambda_zip.output_path
  runtime       = "python3.11"
  handler       = "soar_response_agent.lambda_handler" # filename.handler_function_name
  package_type  = "Zip"                                # defaults to zip
  timeout       = 300                                  # timeout in seconds
  # default memory size is 128MB

  environment {
    variables = {
      BEDROCK_MODEL_ID           = local.llm_model_id
      CORRELATION_FINDINGS_TABLE = aws_dynamodb_table.waf_correlation_findings_table.name
      SECURITY_INCIDENTS_TABLE   = aws_dynamodb_table.security_incidents_table.name
      SNS_TOPIC_ARN              = aws_sns_topic.soar_response_topic.arn
      ENABLE_BEDROCK             = var.enable_bedrock_for_soar_response_agent
    }
  }
  depends_on       = [aws_cloudwatch_log_group.soar_response_agent_lambda_logs]
  source_code_hash = data.archive_file.soar_response_agent_lambda_zip.output_base64sha256
}


