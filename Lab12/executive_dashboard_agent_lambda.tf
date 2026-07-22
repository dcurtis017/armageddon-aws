# s3 bucket for storing reports
resource "aws_s3_bucket" "executive_dashboard_bucket" {
  bucket        = var.executive_dashboard_bucket_name
  force_destroy = true
}

# permissions
resource "aws_iam_policy" "executive_dashboard_agent_policy" {
  name = "executive-dashboard-agent-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.executive_dashboard_bucket.arn}/*"
      },
      {
        Action = ["dynamodb:Scan"]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.waf_correlation_findings_table.arn,
          aws_dynamodb_table.security_incidents_table.arn,
          aws_dynamodb_table.waf_events_table.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "executive_dashboard_agent_lambda_execution_role" {
  name               = "executive_dashboard_agent_lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json
}

resource "aws_iam_role_policy_attachment" "executive_dashboard_agent_lambda_basic" {
  role       = aws_iam_role.executive_dashboard_agent_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "executive_dashboard_agent_bedrock_invoke" {
  role       = aws_iam_role.executive_dashboard_agent_lambda_execution_role.name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

resource "aws_iam_role_policy_attachment" "executive_dashboard_agent_policy" {
  role       = aws_iam_role.executive_dashboard_agent_lambda_execution_role.name
  policy_arn = aws_iam_policy.executive_dashboard_agent_policy.arn
}

# lambda
resource "aws_cloudwatch_log_group" "executive_dashboard_agent_lambda_logs" {
  name              = "/aws/lambda/${local.executive_dashboard_agent_function_name}"
  retention_in_days = 3
}

resource "null_resource" "pip_install" {
  triggers = {
    requirements_hash = filesha256("${path.module}/src/requirements.txt")
  }
  # use manylinux2014_aarch64 for arm
  provisioner "local-exec" {
    command = "python3 -m pip install --platform manylinux2014_x86_64 --implementation cp --python-version 3.13 --only-binary=:all: --upgrade -r ${path.module}/src/requirements.txt -t ${path.module}/src/layer/python"
  }
}

data "archive_file" "layer_archive" {
  type        = "zip"
  source_dir  = "${path.module}/src/layer"
  output_path = "${path.module}/src/layer.zip"
  depends_on  = [null_resource.pip_install]
}

resource "aws_lambda_layer_version" "executive_dashboard_agent_layer" {
  layer_name          = "executive_dashboard_agent_layer"
  filename            = data.archive_file.layer_archive.output_path
  compatible_runtimes = ["python3.13"]
  source_code_hash    = data.archive_file.layer_archive.output_base64sha256
}

data "archive_file" "executive_dashboard_agent_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/executive-dashboard-agent.py"
  output_path = "${path.module}/src/executive-dashboard-agent-lambda.zip"
}

resource "aws_lambda_function" "executive_dashboard_agent_lambda" {
  function_name = local.executive_dashboard_agent_function_name
  role          = aws_iam_role.executive_dashboard_agent_lambda_execution_role.arn
  filename      = data.archive_file.executive_dashboard_agent_lambda_zip.output_path
  runtime       = "python3.13"
  handler       = "executive-dashboard-agent.lambda_handler" # filename.handler_function_name
  package_type  = "Zip"                                      # defaults to zip
  timeout       = 300                                        # timeout in seconds
  memory_size   = 1024                                       # default memory size is 128MB
  ephemeral_storage {
    size = 512 # size in MB
  }

  environment {
    variables = {
      BEDROCK_MODEL_ID           = local.llm_model_id
      CORRELATION_FINDINGS_TABLE = aws_dynamodb_table.waf_correlation_findings_table.name
      SECURITY_INCIDENTS_TABLE   = aws_dynamodb_table.security_incidents_table.name
      WAF_EVENTS_TABLE           = aws_dynamodb_table.waf_events_table.name
      REPORT_BUCKET              = aws_s3_bucket.executive_dashboard_bucket.id
      REPORT_PREFIX              = "executive-reports"
      ENABLE_BEDROCK             = var.enable_bedrock_for_soar_response_agent
      REPORT_PERIOD_HOURS        = 24
      MAX_ITEMS_PER_TABLE        = 5000
      ORGANIZATION_NAME          = "SEIR Cloud Security"
      REPORT_TITLE               = "Executive Security Report"
    }
  }

  layers           = [aws_lambda_layer_version.executive_dashboard_agent_layer.arn]
  depends_on       = [aws_cloudwatch_log_group.executive_dashboard_agent_lambda_logs]
  source_code_hash = data.archive_file.executive_dashboard_agent_lambda_zip.output_base64sha256
}
# scheduler rule
# permissions
resource "aws_iam_role" "eventbridge_scheduler_role" {
  name = "eventbridge-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "scheduler_lambda_policy" {
  name = "scheduler-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.executive_dashboard_agent_lambda.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "schedule_role_attachment_lambda" {
  role       = aws_iam_role.eventbridge_scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_lambda_policy.arn
}

# schedule -- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule
resource "aws_scheduler_schedule" "detection_schedule" {
  count      = 0
  name       = "run-detection-lambda"
  group_name = "default"
  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 0 * * ? *)" # run nightly at midnight # "rate(10 minute)"

  target {
    arn      = aws_lambda_function.executive_dashboard_agent_lambda.arn
    role_arn = aws_iam_role.eventbridge_scheduler_role.arn

    # no custom payload
  }
}
