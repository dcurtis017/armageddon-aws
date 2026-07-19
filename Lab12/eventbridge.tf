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
        Resource = aws_lambda_function.waf_analyzer_lambda.arn
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

  schedule_expression = "rate(10 minute)"

  target {
    arn      = aws_lambda_function.waf_analyzer_lambda.arn
    role_arn = aws_iam_role.eventbridge_scheduler_role.arn

    # no custom payload
  }
}
