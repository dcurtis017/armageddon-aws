##############################
#      WAF EVENTS TABLE      #
##############################
// dynamodb table -- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table
resource "aws_dynamodb_table" "waf_events_table" {
  name         = var.waf_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  attribute {
    name = "event_id"
    type = "S"
  }
}

resource "aws_iam_policy" "waf_events_table_policy" {
  name = "waf-events-table-rw-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          //"dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = [aws_dynamodb_table.waf_events_table.arn, "${aws_dynamodb_table.waf_events_table.arn}/index/*"]
      }
    ]
  })
}

resource "aws_iam_policy" "waf_events_table_policy_ro" {
  name = "waf-events-table-ro-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = [aws_dynamodb_table.waf_events_table.arn, "${aws_dynamodb_table.waf_events_table.arn}/index/*"]
      }
    ]
  })
}

resource "aws_ssm_parameter" "waf_events_table" {
  name  = "/${var.cognito_app_name}/waf_events_table"
  type  = "String"
  value = aws_dynamodb_table.waf_events_table.name
}


#########################################
#   WAF CORRELATION FINDINGS TABLE      #
#########################################
resource "aws_dynamodb_table" "waf_correlation_findings_table" {
  name         = var.waf_correlation_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "finding_id"
  attribute {
    name = "finding_id"
    type = "S"
  }
}

resource "aws_iam_policy" "waf_correlation_findings_table" {
  name = "waf-correlation-findings-table-rw-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          //"dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = [aws_dynamodb_table.waf_correlation_findings_table.arn, "${aws_dynamodb_table.waf_correlation_findings_table.arn}/index/*"]
      }
    ]
  })
}

resource "aws_ssm_parameter" "waf_correlation_findings_table" {
  name  = "/${var.cognito_app_name}/waf_correlation_findings_table"
  type  = "String"
  value = aws_dynamodb_table.waf_correlation_findings_table.name
}
