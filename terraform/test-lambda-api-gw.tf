

resource "aws_api_gateway_rest_api" "api-test_lambda" {
  name = "api-test_lambda"
}

resource "aws_api_gateway_resource" "resource" {
  path_part   = "resource"
  parent_id   = aws_api_gateway_rest_api.api-test_lambda.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api-test_lambda.id
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api-test_lambda.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_test-lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api-test_lambda.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.test_lambda.invoke_arn
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:ap-northeast-2:${var.account_id}:${aws_api_gateway_rest_api.api-test_lambda.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.resource.path}"
}

resource "aws_api_gateway_deployment" "api-test_lambda-deployment" {
  rest_api_id = aws_api_gateway_rest_api.api-test_lambda.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api-test_lambda.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "test-s1" {
  deployment_id = aws_api_gateway_deployment.api-test_lambda-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api-test_lambda.id
  stage_name    = "test-s1"
}