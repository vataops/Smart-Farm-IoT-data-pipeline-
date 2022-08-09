data "archive_file" "test_lambda_function" {
  type = "zip"

  source_dir  = "${path.module}/../test-lambda"
  output_path = "${path.module}/test-lambda.zip"
}

resource "aws_s3_bucket" "test-lambda-bucket" {
  bucket = "test-lambda-src-bucket"
  acl = "private"
  force_destroy = true
}

resource "aws_s3_object" "test-lambda" {
  bucket = aws_s3_bucket.test-lambda-bucket.id

  key    = "test-lambda.zip"
  source = data.archive_file.test_lambda_function.output_path

  etag = filemd5(data.archive_file.test_lambda_function.output_path)
}

resource "aws_iam_role" "test_lambda_role" {
  name = "test-lambda-role"

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

resource "aws_iam_role_policy" "test-lambda-policy" {
  name = "test-lambda-policy"
  role = aws_iam_role.test_lambda_role.id

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

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a 
  # path.module in the filename.
  s3_bucket = aws_s3_bucket.test-lambda-bucket.id
  s3_key = aws_s3_object.test-lambda.key
  function_name = "test_lambda"
  role          = aws_iam_role.test_lambda_role.arn
  handler       = "test-handler.hello"
  layers        = [aws_lambda_layer_version.test_lambda_layer.arn]
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

resource "aws_lambda_layer_version" "test_lambda_layer" {
  filename   = "${path.module}/python.zip"
  layer_name = "test_lambda_layer"

  compatible_runtimes = ["python3.8","python3.9"]
}

resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.arn
  principal     = "apigateway.amazonaws.com"
}