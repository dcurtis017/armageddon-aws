resource "aws_iam_role" "waf_analyzer_lambda_execution_role" {
  name               = "waf_analyzer_lambda_lab_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "waf_analyzer_lambda_basic" {
  role       = aws_iam_role.waf_analyzer_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "waf_analyzer_bedrock_invoke" {
  role       = aws_iam_role.waf_analyzer_lambda_execution_role.name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

resource "aws_iam_role_policy_attachment" "waf_analyzer_filter_waf_logs" {
  role       = aws_iam_role.waf_analyzer_lambda_execution_role.name
  policy_arn = aws_iam_policy.filter_waf_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "waf_analyzer_lambda_dynamodb" {
  role       = aws_iam_role.waf_analyzer_lambda_execution_role.name
  policy_arn = aws_iam_policy.waf_events_table_policy.arn
}

resource "aws_cloudwatch_log_group" "waf_analyzer_lambda_logs" {
  name              = "/aws/lambda/${local.waf_analyzer_lambda}"
  retention_in_days = 3
}

data "archive_file" "waf_analyzer_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/waf_bedrock_analyzer.py"
  output_path = "${path.module}/src/waf-analyzer-lambda.zip"
}

resource "aws_lambda_function" "waf_analyzer_lambda" {
  function_name = local.waf_analyzer_lambda
  role          = aws_iam_role.waf_analyzer_lambda_execution_role.arn
  filename      = data.archive_file.waf_analyzer_lambda_zip.output_path
  runtime       = "python3.11"
  handler       = "waf_bedrock_analyzer.lambda_handler" # filename.handler_function_name
  package_type  = "Zip"                                 # defaults to zip
  timeout       = 300                                   # timeout in seconds
  # default memory size is 128MB

  environment {
    variables = {
      BEDROCK_MODEL_ID = local.llm_model_id
      DYNAMODB_TABLE   = aws_dynamodb_table.waf_events_table.name
      WAF_LOG_GROUP    = aws_cloudwatch_log_group.waf_log_group.name
      LOOKBACK_MINUTES = 5
      MAX_LOG_EVENTS   = 10
    }
  }
  depends_on       = [aws_cloudwatch_log_group.waf_analyzer_lambda_logs]
  source_code_hash = data.archive_file.waf_analyzer_lambda_zip.output_base64sha256
}
