# the api container itself
resource "aws_api_gateway_rest_api" "api" {
  name = "Lambda-Class-Labs"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  name          = "CognitoLambdaAuthorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  provider_arns = [aws_cognito_user_pool.user_pool.arn]
}


resource "aws_api_gateway_resource" "python" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "python"
}
resource "aws_api_gateway_resource" "node" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "node"
}

# lambda returns a full http response so we don't need method or integration responses
resource "aws_api_gateway_method" "python_method" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.python.id
  http_method          = "GET"
  authorization        = "COGNITO_USER_POOLS"
  authorizer_id        = aws_api_gateway_authorizer.lambda_authorizer.id
  authorization_scopes = ["aws.cognito.signin.user.admin"] # this is the scope will allow us to take an auth token not an id token
}

resource "aws_api_gateway_method" "node_method" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.node.id
  http_method          = "GET"
  authorization        = "COGNITO_USER_POOLS"
  authorizer_id        = aws_api_gateway_authorizer.lambda_authorizer.id
  authorization_scopes = ["aws.cognito.signin.user.admin"] # this is the scope will allow us to take an auth token not an id token
}

# lambda integration
resource "aws_api_gateway_integration" "python_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.python.id
  http_method             = aws_api_gateway_method.python_method.http_method
  integration_http_method = "POST" # this must be post -- In this method, Lambda requires that the POST request be used to invoke any Lambda function.
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.python_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "node_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.node.id
  http_method             = aws_api_gateway_method.node_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.node_lambda.invoke_arn
}

# deployment 

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  lifecycle {
    create_before_destroy = true
  }


  depends_on = [
    aws_api_gateway_integration.node_integration,
    aws_api_gateway_integration.python_integration
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}

# permissions
resource "aws_lambda_permission" "api_python" {
  statement_id  = "AllowAPIGWInvokePythonLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.python_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*" # allow form any stage, method, resource...
}

resource "aws_lambda_permission" "api_node" {
  statement_id  = "AllowAPIGWInvokeNodeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.node_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*" # allow form any stage, method, resource...
}

