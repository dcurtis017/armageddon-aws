output "python_sample_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/python?name=Python_Guy"
}
output "node_sample_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/node?name=Node_Guy"
}

output "api_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}

output "client_id" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}

output "use_secret" {
  value = var.use_secret
}

output "client_secret_ssm_parameter" {
  value = one(aws_ssm_parameter.client_secret[*].name) # use one to get null if there are no items in the list or one element as a single valeu
}
output "admin_user_username_ssm_parameter" {
  value = aws_ssm_parameter.admin_user_username.name
}
output "admin_user_password_ssm_parameter" {
  value = aws_ssm_parameter.admin_user_password.name
}
output "student_user_username_ssm_parameter" {
  value = aws_ssm_parameter.student_user_username.name
}
output "student_user_password_ssm_parameter" {
  value = aws_ssm_parameter.student_user_password.name
}
output "anon_user_username_ssm_parameter" {
  value = aws_ssm_parameter.anon_user_username.name
}
output "anon_user_password_ssm_parameter" {
  value = aws_ssm_parameter.anon_user_password.name
}
output "python_lambda_arn" {
  value = aws_lambda_function.python_lambda.arn
}
output "node_lambda_arn" {
  value = aws_lambda_function.node_lambda.arn
}
output "waf_analyzer_lambda_arn" {
  value = aws_lambda_function.waf_analyzer_lambda.arn
}
output "waf_threat_correlation_lambda_arn" {
  value = aws_lambda_function.waf_threat_correlation_lambda.arn
}
