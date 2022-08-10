data "archive_file" "pseudo_sensor_log_lambda_function" {
  type = "zip"

  source_dir  = "${path.module}/../pseudo_sensor_log_lambda"
  output_path = "${path.module}/pseudo_sensor_log_lambda.zip"
}

resource "aws_s3_bucket" "pseudo_sensor_log_lambda_bucket" {
  bucket = "pseudo-sensor-log-lambda-src-bucket"
  acl = "private"
  force_destroy = true
}

resource "aws_s3_object" "pseudo_sensor_log_lambda" {
  bucket = aws_s3_bucket.pseudo_sensor_log_lambda_bucket.id

  key    = "pseudo_sensor_log_lambda.zip"
  source = data.archive_file.pseudo_sensor_log_lambda_function.output_path

  etag = filemd5(data.archive_file.pseudo_sensor_log_lambda_function.output_path)
}

resource "aws_iam_role" "pseudo_sensor_log_lambda_role" {
  name = "pseudo-sensor-log-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "pseudo_sensor_log_lambda_policy" {
  name = "pseudo-sensor-log-lambda-policy"
  role = aws_iam_role.pseudo_sensor_log_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
                "s3:*",
                "s3-object-lambda:*",
                "logs:CreateLogStream",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_lambda_function" "pseudo_sensor_log_lambda" {
  # If the file is not in the current working directory you will need to include a 
  # path.module in the filename.
  s3_bucket = aws_s3_bucket.pseudo_sensor_log_lambda_bucket.id
  s3_key = aws_s3_object.pseudo_sensor_log_lambda.key
  function_name = "pseudo_sensor_log_lambda"
  role          = aws_iam_role.pseudo_sensor_log_lambda_role.arn
  handler       = "test-handler.hello"
  layers        = [aws_lambda_layer_version.pseudo_sensor_log_lambda_layer.arn]
  timeout       = 300
  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  /* source_code_hash = filebase64sha256("lambda_function_payload.zip") */

  runtime = "python3.8"

  environment {
    variables = {
        API_ENDPOINT = "${aws_api_gateway_stage.s1.invoke_url}/streams/${aws_kinesis_stream.test_stream.name}/record"
      }
  }
}

resource "aws_lambda_layer_version" "pseudo_sensor_log_lambda_layer" {
  filename   = "${path.module}/python.zip"
  layer_name = "pseudo_sensor_log_lambda_layer"

  compatible_runtimes = ["python3.8","python3.9"]
}

resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pseudo_sensor_log_lambda.arn
  principal     = "apigateway.amazonaws.com"
}



resource "aws_api_gateway_rest_api" "pseudo_api_gw" {
  name = "pseudo_api_gw"
}

resource "aws_api_gateway_resource" "resource" {
  path_part   = "resource"
  parent_id   = aws_api_gateway_rest_api.pseudo_api_gw.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.pseudo_api_gw.id
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.pseudo_api_gw.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "pseudo_sensor_log_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.pseudo_api_gw.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.pseudo_sensor_log_lambda.invoke_arn
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pseudo_sensor_log_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:ap-northeast-2:${var.account_id}:${aws_api_gateway_rest_api.pseudo_api_gw.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.resource.path}"
}

resource "aws_api_gateway_deployment" "pseudo_api_gw-deployment" {
  rest_api_id = aws_api_gateway_rest_api.pseudo_api_gw.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.resource.id,
      aws_api_gateway_method.method.id,
      aws_api_gateway_integration.pseudo_sensor_log_lambda_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "test-s1" {
  deployment_id = aws_api_gateway_deployment.pseudo_api_gw-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.pseudo_api_gw.id
  stage_name    = "test-s1"
}