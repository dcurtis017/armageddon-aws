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
