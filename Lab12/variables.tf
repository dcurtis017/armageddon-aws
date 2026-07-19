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
