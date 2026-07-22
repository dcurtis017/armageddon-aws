resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda_lab_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_doc.json
}

# lambda policies
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

###############################################
# LAMBDA FUNCTIONS                            #
###############################################

# PYTHON ENDPOINT

data "archive_file" "python_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/basic-lambda.py"
  output_path = "${path.module}/src/basic-python-lambda.zip"
}

resource "aws_cloudwatch_log_group" "python_lambda_logs" {
  name              = "/aws/lambda/${local.python_lambda_function_name}"
  retention_in_days = 3
}

resource "aws_lambda_function" "python_lambda" {
  function_name = local.python_lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  filename      = data.archive_file.python_lambda_zip.output_path
  runtime       = "python3.11"
  handler       = "basic-lambda.lambda_handler" # filename.handler_function_name
  package_type  = "Zip"                         # defaults to zip
  # default memory size is 128MB

  environment {
    variables = {
    }
  }
  depends_on       = [aws_cloudwatch_log_group.python_lambda_logs]
  source_code_hash = data.archive_file.python_lambda_zip.output_base64sha256
}

# NODEJS ENDPOINT
data "archive_file" "node_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/basic-lambda.js"
  output_path = "${path.module}/src/basic-node-lambda.zip"
}

resource "aws_cloudwatch_log_group" "node_lambda_logs" {
  name              = "/aws/lambda/${local.node_lambda_function_name}"
  retention_in_days = 3
}
resource "aws_lambda_function" "node_lambda" {
  function_name = local.node_lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  filename      = data.archive_file.node_lambda_zip.output_path
  runtime       = "nodejs24.x"
  handler       = "basic-lambda.handler" # filename.handler_function_name
  package_type  = "Zip"                  # defaults to zip
  # default memory size is 128MB

  environment {
    variables = {

    }
  }
  depends_on       = [aws_cloudwatch_log_group.node_lambda_logs]
  source_code_hash = data.archive_file.node_lambda_zip.output_base64sha256
}
