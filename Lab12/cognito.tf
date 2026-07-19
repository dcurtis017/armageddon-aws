// user pool -- https://registry.terraform.io/providers/hashicorp/awS/6.42.0/docs/resources/cognito_user_pool
resource "aws_cognito_user_pool" "user_pool" {
  name              = "${var.cognito_app_name}-user-pool"
  mfa_configuration = var.mfa_configuration
  user_pool_tier    = "ESSENTIALS" // https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-sign-in-feature-plans.html

  alias_attributes = ["email"]

  auto_verified_attributes = ["email"]

  dynamic "email_mfa_configuration" {
    for_each = var.mfa_configuration == "ON" ? ["email"] : []
    content {
      subject = "Your MFA Code"
      message = "Your MFA code is {####}"
    }
  }

  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration == "ON" ? ["software_token"] : []
    content {
      enabled = true
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }
}

// cognito domain  -- required to login with ui

resource "random_integer" "random_num" {
  min = 1000
  max = 9999
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain                = "bmc74xk1snnn-${random_integer.random_num.id}"
  user_pool_id          = aws_cognito_user_pool.user_pool.id
  managed_login_version = 2 // 1 hosted ui 2 managed login with branding designer
}

// app client -- https://registry.terraform.io/providers/-/aws/6.30.0/docs/resources/cognito_user_pool_client
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name            = "${var.cognito_app_name}-client"
  user_pool_id    = aws_cognito_user_pool.user_pool.id
  generate_secret = var.use_secret
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
  auth_session_validity                = 15
  access_token_validity                = 12 // 12 hours
  id_token_validity                    = 12 // 12 hours
  enable_token_revocation              = true
  prevent_user_existence_errors        = "ENABLED" // this prevents us from getting different error messages when we try to sign up with an email that already exists vs one that doesn't exist, which is a security best practice
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = [
    "http://localhost:5173/callback" // temporarry
  ]

  logout_urls = [
    "http://localhost:5173/logout"
  ]

  supported_identity_providers = ["COGNITO"]
}

// style for login page -- https://registry.terraform.io/providers/-/aws/latest/docs/resources/cognito_managed_login_branding
resource "aws_cognito_managed_login_branding" "branding" {
  user_pool_id                = aws_cognito_user_pool.user_pool.id
  client_id                   = aws_cognito_user_pool_client.user_pool_client.id
  use_cognito_provided_values = true
}


// groups -- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group
resource "aws_cognito_user_group" "admin_group" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Admin group with elevated permissions"
  precedence   = 1
}
resource "aws_cognito_user_group" "student_group" {
  name         = "student"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Student group with limited permissions"
  precedence   = 2
}

resource "aws_cognito_user" "test_user1" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = var.test_user_1_username
  attributes = {
    email          = var.test_user_1_email
    name           = "DCTest1 Admin"
    email_verified = true
  }
  password = "Hello123!"
}

resource "aws_cognito_user_in_group" "test_user1_admin_group" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = aws_cognito_user.test_user1.username
  group_name   = aws_cognito_user_group.admin_group.name
}
resource "aws_cognito_user_in_group" "test_user1_student_group" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = aws_cognito_user.test_user1.username
  group_name   = aws_cognito_user_group.student_group.name
}

resource "aws_cognito_user" "test_user2" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = var.test_user_2_username
  attributes = {
    email          = var.test_user_2_email
    name           = "DCTest1 Student"
    email_verified = true
  }
  password = "Hello123!"
}

resource "aws_cognito_user_in_group" "test_user2_student_group" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = aws_cognito_user.test_user2.username
  group_name   = aws_cognito_user_group.student_group.name
}

resource "aws_cognito_user" "test_user3" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = var.test_user_3_username
  attributes = {
    email          = var.test_user_3_email
    name           = "DCTest1 NoGroup"
    email_verified = true
  }
  password = "Hello123!"
}

resource "aws_ssm_parameter" "client_secret" {
  count = var.use_secret ? 1 : 0
  name  = "/${var.cognito_app_name}/client_secret"
  type  = "SecureString"
  value = aws_cognito_user_pool_client.user_pool_client.client_secret
}

resource "aws_ssm_parameter" "admin_user_username" {
  name  = "/${var.cognito_app_name}/admin_username"
  type  = "String"
  value = aws_cognito_user.test_user1.username
}

resource "aws_ssm_parameter" "admin_user_password" {
  name  = "/${var.cognito_app_name}/admin_password"
  type  = "SecureString"
  value = aws_cognito_user.test_user1.password
}

resource "aws_ssm_parameter" "student_user_username" {
  name  = "/${var.cognito_app_name}/student_username"
  type  = "String"
  value = aws_cognito_user.test_user2.username
}

resource "aws_ssm_parameter" "student_user_password" {
  name  = "/${var.cognito_app_name}/student_password"
  type  = "SecureString"
  value = aws_cognito_user.test_user2.password
}

resource "aws_ssm_parameter" "anon_user_username" {
  name  = "/${var.cognito_app_name}/anon_username"
  type  = "String"
  value = aws_cognito_user.test_user3.username
}

resource "aws_ssm_parameter" "anon_user_password" {
  name  = "/${var.cognito_app_name}/anon_password"
  type  = "SecureString"
  value = aws_cognito_user.test_user3.password
}
