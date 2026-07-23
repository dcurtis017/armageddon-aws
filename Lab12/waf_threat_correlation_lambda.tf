resource "aws_iam_policy" "waf_threat_correlation_policy" {
  name = "waf-thret-correlation-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["events:PutEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:events:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:event-bus/${var.waf_correlation_bus_name}"
      }
    ]
  })
}

resource "aws_iam_role" "waf_threat_correlation_lambda_execution_role" {
  name               = "waf_threat_correlation_lambda_lab_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "waf_threat_correlation_lambda_basic" {
  role       = aws_iam_role.waf_threat_correlation_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "waf_threat_correlation_filter_waf_logs" {
  role       = aws_iam_role.waf_threat_correlation_lambda_execution_role.name
  policy_arn = aws_iam_policy.filter_waf_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "waf_threat_correlation_bedrock_invoke" {
  role       = aws_iam_role.waf_threat_correlation_lambda_execution_role.name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

resource "aws_iam_role_policy_attachment" "waf_threat_correlation_policy" {
  role       = aws_iam_role.waf_threat_correlation_lambda_execution_role.name
  policy_arn = aws_iam_policy.waf_threat_correlation_policy.arn
}

resource "aws_iam_role_policy_attachment" "waf_correlation_findings" {
  role       = aws_iam_role.waf_threat_correlation_lambda_execution_role.name
  policy_arn = aws_iam_policy.waf_correlation_findings_table.arn
}

resource "aws_iam_role_policy_attachment" "waf_analyzer_lambda_waf_events_ro" {
  role       = aws_iam_role.waf_threat_correlation_lambda_execution_role.name
  policy_arn = aws_iam_policy.waf_events_table_policy_ro.arn
}

resource "aws_cloudwatch_log_group" "waf_threat_correlation_lambda_logs" {
  name              = "/aws/lambda/${local.waf_threat_correlation_lambda}"
  retention_in_days = 3
}

data "archive_file" "waf_threat_correlation_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/waf_threat_correlation_agent.py"
  output_path = "${path.module}/src/waf-threat-correlation-agent-lambda.zip"
}

resource "aws_lambda_function" "waf_threat_correlation_lambda" {
  function_name = local.waf_threat_correlation_lambda
  role          = aws_iam_role.waf_threat_correlation_lambda_execution_role.arn
  filename      = data.archive_file.waf_threat_correlation_lambda_zip.output_path
  runtime       = "python3.11"
  handler       = "waf_threat_correlation_agent.lambda_handler" # filename.handler_function_name
  package_type  = "Zip"                                         # defaults to zip
  timeout       = 600                                           # timeout in seconds
  # default memory size is 128MB

  environment {
    variables = {
      BEDROCK_MODEL_ID           = local.llm_model_id
      WAF_EVENTS_TABLE           = aws_dynamodb_table.waf_events_table.name
      CORRELATION_FINDINGS_TABLE = aws_dynamodb_table.waf_correlation_findings_table.name
      WAF_LOG_GROUP              = aws_cloudwatch_log_group.waf_log_group.name
      CORRELATION_WINDOW_MINUTES = 60
      MINIMUM_EVENT_COUNT        = 3
      MAX_EVENTS                 = 500
      EVENTBRIDGE_BUS_NAME       = var.waf_correlation_bus_name
      EVENTBRIDGE_SOURCE         = var.waf_correlation_event_source
    }
  }
  depends_on       = [aws_cloudwatch_log_group.waf_threat_correlation_lambda_logs]
  source_code_hash = data.archive_file.waf_threat_correlation_lambda_zip.output_base64sha256
}

# scheduler rule
# schedule -- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule
resource "aws_scheduler_schedule" "waf_threat_correlation_schedule" {
  name       = "run-waf-threat-correlation-lambda-schedule"
  group_name = "default"
  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(60 minute)" # since we don't set start date, the first execution is after deployment

  target {
    arn      = aws_lambda_function.waf_threat_correlation_lambda.arn
    role_arn = aws_iam_role.eventbridge_scheduler_role.arn

    # no custom payload
  }
}
