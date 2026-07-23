# Policies that are used by multiple lambda functions
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
        Effect = "Allow"
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:inference-profile/${local.llm_model_id}",
          var.default_bedrock_foundation_model_arn
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "filter_waf_logs_policy" {
  name = "filter-waf-logs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:FilterLogEvents"]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.waf_log_group.arn}:*"
      }
    ]
  })
}

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
        Resource = [aws_lambda_function.executive_dashboard_agent_lambda.arn, aws_lambda_function.waf_threat_correlation_lambda.arn, aws_lambda_function.waf_analyzer_lambda.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "schedule_role_attachment_lambda" {
  role       = aws_iam_role.eventbridge_scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_lambda_policy.arn
}
