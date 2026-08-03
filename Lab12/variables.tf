variable "mfa_configuration" {
  type    = string
  default = "OFF"
  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be either OFF, ON, or OPTIONAL"
  }
}

variable "use_secret" {
  type    = bool
  default = false
}

variable "cognito_app_name" {
  type    = string
  default = "bmc-class7-cognito-app"
}

variable "project_name" {
  type    = string
  default = "bmc-class7-armageddon"
}

variable "project_region" {
  type    = string
  default = "us-east-2"
}

variable "waf_table_name" {
  type    = string
  default = "waf-events"
}

variable "waf_correlation_table_name" {
  type    = string
  default = "waf-correlation-findings"
}

variable "test_user_1_email" {
  type = string
}

variable "test_user_2_email" {
  type = string
}

variable "test_user_3_email" {
  type = string
}

variable "test_user_1_username" {
  type = string
}

variable "test_user_2_username" {
  type = string
}

variable "test_user_3_username" {
  type = string
}

variable "waf_correlation_bus_name" {
  type    = string
  default = "default"
}

variable "waf_correlation_event_source" {
  type    = string
  default = "seir.waf.correlation"
}

variable "soar_sns_topic_name" {
  type    = string
  default = "soar-response-topic"
}

variable "soar_sns_email_endpoint" {
  type = string
}

variable "security_incidents_table_name" {
  type    = string
  default = "security-incidents"
}

variable "enable_bedrock_for_soar_response_agent" {
  type    = bool
  default = true
}

variable "executive_dashboard_bucket_name" {
  type    = string
  default = "bmc-class7-executive-dashboard"
}

variable "default_bedrock_model_id" {
  type    = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "default_bedrock_foundation_model_arn" {
  type = string
}

variable "soar_critical_alerts_topic_name" {
  type    = string
  default = "soar-critical-alerts-topic"
}
