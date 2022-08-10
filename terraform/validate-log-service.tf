resource "aws_iam_role" "lambda_role" {
  name = "validate-lambda-policy"

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

data "aws_iam_policy" "S3FullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = data.aws_iam_policy.S3FullAccess.arn
}

data "archive_file" "lambda_function" {
  type = "zip"

  source_dir  = "${path.module}/../validate-lambda"
  output_path = "${path.module}/validate-lambda.zip"
}

resource "aws_s3_bucket" "validate-lambda-bucket" {
  bucket = "validate-lambda-bucket"
  acl = "private"
  force_destroy = true
}

resource "aws_s3_object" "validate-lambda" {
  bucket = aws_s3_bucket.validate-lambda-bucket.id

  key    = "validate-lambda.zip"
  source = data.archive_file.lambda_function.output_path

  etag = filemd5(data.archive_file.lambda_function.output_path)
}

resource "aws_lambda_function" "lambda_function" {

  s3_bucket = aws_s3_bucket.validate-lambda-bucket.id
  s3_key = aws_s3_object.validate-lambda.key
  function_name = "validate_log_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.hello"

  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  runtime = "python3.8"
  memory_size = 1024

  layers = ["arn:aws:lambda:ap-northeast-2:336392948345:layer:AWSDataWrangler-Python38:5"]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_role_policy,
    aws_cloudwatch_log_group.lambda_log,
  ]

  environment {
    variables = {
      DEST_S3_NAME = aws_s3_bucket.spike-bucket.bucket,
      HOOK_URL = var.HOOK_URL
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/validate_log_lambda"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "validate-lambda-log-policy"
  path        = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.tf-dummy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy_2" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_s3_bucket" "spike-bucket" {
  bucket = "spike-log-bucket"
  acl = "private"
  force_destroy = true
}

data "aws_iam_policy_document" "spike_bucket_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      aws_s3_bucket.spike-bucket.arn,
      "${aws_s3_bucket.spike-bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.tf-dummy.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_function.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_bucket,
  ]
}