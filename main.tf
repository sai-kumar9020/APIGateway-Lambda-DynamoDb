provider "aws" {
  region = var.aws_region
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_contact_form"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy_contact_form"
  description = "Allow Lambda to access DynamoDB, SES, and logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["logs:*"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["dynamodb:PutItem"],
        Resource = aws_dynamodb_table.contact_table.arn
      },
      {
        Effect = "Allow",
        Action = ["ses:SendEmail"],
        Resource = "*"
      }
    ]
  })
}

# Attach IAM policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# DynamoDB Table
resource "aws_dynamodb_table" "contact_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# SES Email Identities
resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

resource "aws_ses_email_identity" "recipient" {
  email = var.recipient_email
}

# Archive the Lambda source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda Function
resource "aws_lambda_function" "contact_handler" {
  function_name = "handleContactForm"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      TABLE_NAME      = var.dynamodb_table_name
      SENDER_EMAIL    = var.sender_email
      RECIPIENT_EMAIL = var.recipient_email
    }
  }
}

# API Gateway - Create REST API
resource "aws_api_gateway_rest_api" "contact_api" {
  name = "contactFormAPI"
}

# /contact resource
resource "aws_api_gateway_resource" "contact" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  parent_id   = aws_api_gateway_rest_api.contact_api.root_resource_id
  path_part   = "contact"
}

# POST Method
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  resource_id   = aws_api_gateway_resource.contact.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda Integration for POST
resource "aws_api_gateway_integration" "lambda_post" {
  rest_api_id             = aws_api_gateway_rest_api.contact_api.id
  resource_id             = aws_api_gateway_resource.contact.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"  # Lambda Proxy Integration ,API Gateway forwards the full HTTP request to Lambda as-is, and expects a specific response format.
  uri                     = aws_lambda_function.contact_handler.invoke_arn
}


# Lambda permission for API Gateway
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.contact_api.execution_arn}/*/*"
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.lambda_post]
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
}

# Stage for deployment
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  stage_name    = "prod"
}
