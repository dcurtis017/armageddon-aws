resource "aws_wafv2_web_acl" "waf" {
  name  = "lambda-lab-waf"
  scope = "REGIONAL"
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true  # wheter the resource sends metrics to cloudwatch
    metric_name                = "waf" # name of the cloudwatch metric
    sampled_requests_enabled   = true  # store samplings of requests that match the rules
  }

  # Prevent Terraform from managing inline rules -- prevents terraform from trying to overwrite rules managed externally to avoid state drift
  lifecycle {
    ignore_changes = [rule]
  }
}

# https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html
resource "aws_wafv2_web_acl_rule" "common_rule" {
  name        = "AWSCommonRules"
  web_acl_arn = aws_wafv2_web_acl.waf.arn
  priority    = 30
  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesCommonRuleSet"
      vendor_name = "AWS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-common-rules"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_rule" "ddos_flood_rule" {
  name        = "RateLimitRule"
  web_acl_arn = aws_wafv2_web_acl.waf.arn
  priority    = 60
  action {
    block {}
  }

  statement {
    rate_based_statement {
      limit              = 1000 # max requests per 5 minute period per IP address
      aggregate_key_type = "IP"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-ddos-flood-rule"
    sampled_requests_enabled   = true
  }
}

# AWS-AWSManagedRulesAntiDDoSRuleSet is paid so maybe see what others have

resource "aws_wafv2_web_acl_rule" "sql_injection_rule" {
  name        = "AWSManagedRulesSQLiRuleSet"
  web_acl_arn = aws_wafv2_web_acl.waf.arn
  priority    = 90
  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesSQLiRuleSet"
      vendor_name = "AWS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-sql-injection-rules"
    sampled_requests_enabled   = true
  }
}

# https://docs.aws.amazon.com/waf/latest/APIReference/API_GeoMatchStatement.html
resource "aws_wafv2_web_acl_rule" "geo_rule" {
  name        = "block-sa-countries"
  web_acl_arn = aws_wafv2_web_acl.waf.arn
  priority    = 2
  action {
    block {}
  }

  statement {
    geo_match_statement {
      country_codes = ["CO", "AR", "BR"]
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true # enable metrics for this rule
    metric_name                = "${var.project_name}-block-countries"
    sampled_requests_enabled   = true # store sample requests that match the rule
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_rule#rate-based-statement
# https://docs.aws.amazon.com/waf/latest/APIReference/API_RateBasedStatement.html
resource "aws_wafv2_web_acl_rule" "rate_limit_rule" {
  name        = "rate-limit-by-ip"
  web_acl_arn = aws_wafv2_web_acl.waf.arn
  priority    = 10
  action {
    block {}
  }

  statement {
    rate_based_statement {
      limit              = 10
      aggregate_key_type = "IP"
      # remember this doesn't mean check every 60 secs, it looks back 60 secs so a burst of traffic might make it through
      evaluation_window_sec = 60 # consider requests in the 60 second window when evaluating the rule
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-rate-limit"
    sampled_requests_enabled   = true
  }
}

# attach waf to api gateway
resource "aws_wafv2_web_acl_association" "api_waf_association" {
  resource_arn = aws_api_gateway_stage.prod.arn # associate with the stage not the gw because security requirements may differ between stages
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}

# logging to s3
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name = "aws-waf-logs-lambda-lab"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging_config" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group.arn]
  resource_arn            = aws_wafv2_web_acl.waf.arn
}

resource "aws_cloudwatch_log_resource_policy" "waf_log_policy" {
  policy_document = data.aws_iam_policy_document.waf_log_policy_doc.json
  policy_name     = "waf-log-policy"
}

data "aws_iam_policy_document" "waf_log_policy_doc" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.waf_log_group.arn}:*"]
    # only allow when the source account is equal to my account
    condition {
      test     = "StringEquals"
      values   = [tostring(data.aws_caller_identity.current.account_id)]
      variable = "aws:SourceAccount"
    }
  }
}
