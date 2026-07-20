# assume role policy for lambda role -- allows lambda to assume your role
data "aws_iam_policy_document" "assume_role_doc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "bedrock_invoke" {
  name = "bedrock-invoke-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel",
          "aws-marketplace:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# lambda role
resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_lab_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json
}

# lambda policies
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

###############################################
# LAMBDA FUNCTIONS                            #
###############################################

# PYTHON ENDPOINT

data "archive_file" "python_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/basic-lambda.py"
  output_path = "${path.module}/src/basic-python-lambda.zip"
}

resource "aws_cloudwatch_log_group" "python_lambda_logs" {
  name              = "/aws/lambda/${local.python_lambda_function_name}"
  retention_in_days = 3
}

resource "aws_lambda_function" "python_lambda" {
  function_name = local.python_lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  filename      = data.archive_file.python_lambda_zip.output_path
  runtime       = "python3.11"
  handler       = "basic-lambda.lambda_handler" # filename.handler_function_name
  package_type  = "Zip"                         # defaults to zip
  # default memory size is 128MB

  environment {
    variables = {
    }
  }
  depends_on       = [aws_cloudwatch_log_group.python_lambda_logs]
  source_code_hash = data.archive_file.python_lambda_zip.output_base64sha256
}

# NODEJS ENDPOINT
data "archive_file" "node_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/basic-lambda.js"
  output_path = "${path.module}/src/basic-node-lambda.zip"
}

resource "aws_cloudwatch_log_group" "node_lambda_logs" {
  name              = "/aws/lambda/${local.node_lambda_function_name}"
  retention_in_days = 3
}
resource "aws_lambda_function" "node_lambda" {
  function_name = local.node_lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  filename      = data.archive_file.node_lambda_zip.output_path
  runtime       = "nodejs24.x"
  handler       = "basic-lambda.handler" # filename.handler_function_name
  package_type  = "Zip"                  # defaults to zip
  # default memory size is 128MB

  environment {
    variables = {

    }
  }
  depends_on       = [aws_cloudwatch_log_group.node_lambda_logs]
  source_code_hash = data.archive_file.node_lambda_zip.output_base64sha256
}

# WAF ANALYZER
resource "aws_iam_policy" "waf_events_policy" {
  name = "waf-events-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel",
          "aws-marketplace:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["logs:FilterLogEvents"]
        Effect   = "Allow"
        Resource = "*" # restrict later to just the waf logs for the app
      }
    ]
  })
}

resource "aws_iam_role" "waf_analyzer_lambda_execution_role" {
  name               = "waf_analyzer_lambda_lab_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "waf_analyzer_lambda_basic" {
  role       = aws_iam_role.waf_analyzer_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "waf_events_policy" {
  role       = aws_iam_role.waf_analyzer_lambda_execution_role.name
  policy_arn = aws_iam_policy.waf_events_policy.arn
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
  output_path = "${path.module}/src/waf-events-lambda.zip"
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

# WAF Threat Correlation Agent
resource "aws_iam_policy" "waf_threat_correlation_policy" {
  name = "waf-thret-correlation-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel",
          "aws-marketplace:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["logs:FilterLogEvents"]
        Effect   = "Allow"
        Resource = "*" # I don't think this one is needed
      },
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
  timeout       = 300                                           # timeout in seconds
  # default memory size is 128MB

  environment {
    variables = {
      BEDROCK_MODEL_ID           = local.llm_model_id
      WAF_EVENTS_TABLE           = aws_dynamodb_table.waf_events_table.name
      CORRELATION_FINDINGS_TABLE = aws_dynamodb_table.waf_correlation_findings_table.name
      WAF_LOG_GROUP              = aws_cloudwatch_log_group.waf_log_group.name
      CORRELATION_WINDOW_MINUTES = 60
      MINIMUM_EVENT_COUNT        = 3
      MAX_EVENTS                 = 100
      EVENTBRIDGE_BUS_NAME       = var.waf_correlation_bus_name
      EVENTBRIDGE_SOURCE         = var.waf_correlation_event_source
    }
  }
  depends_on       = [aws_cloudwatch_log_group.waf_threat_correlation_lambda_logs]
  source_code_hash = data.archive_file.waf_threat_correlation_lambda_zip.output_base64sha256
}
