resource "aws_iam_role" "api_gw_kinesis_role" {
  name = "api_gw_kinesis_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy" "AmazonKinesisFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}

resource "aws_iam_role_policy_attachment" "AmazonKinesisFullAccessAttachment" {
  role       = aws_iam_role.api_gw_kinesis_role.name
  policy_arn = data.aws_iam_policy.AmazonKinesisFullAccess.arn
}

data "aws_iam_policy" "AmazonAPIGatewayPushToCloudWatchLogs" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_role_policy_attachment" "AmazonAPIGatewayPushToCloudWatchLogsAttachment" {
  role       = aws_iam_role.api_gw_kinesis_role.name
  policy_arn = data.aws_iam_policy.AmazonAPIGatewayPushToCloudWatchLogs.arn
}

resource "aws_api_gateway_rest_api" "kinesis-api-gw" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "example"
      version = "1.0"
    }
    paths = {
      "/path1" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
          }
        }
      }
    }
  })

  name = "kinesis-api-gw"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "streams_resource" {
  rest_api_id = aws_api_gateway_rest_api.kinesis-api-gw.id
  parent_id   = aws_api_gateway_rest_api.kinesis-api-gw.root_resource_id
  path_part   = "streams"
}

resource "aws_api_gateway_resource" "stream_name_resource" {
  rest_api_id = aws_api_gateway_rest_api.kinesis-api-gw.id
  parent_id   = aws_api_gateway_resource.streams_resource.id
  path_part   = "{stream-name}"
}

resource "aws_api_gateway_resource" "record_resource" {
  rest_api_id = aws_api_gateway_rest_api.kinesis-api-gw.id
  parent_id   = aws_api_gateway_resource.stream_name_resource.id
  path_part   = "record"
}

resource "aws_api_gateway_method" "putRecord" {
  rest_api_id   = aws_api_gateway_rest_api.kinesis-api-gw.id
  resource_id   = aws_api_gateway_resource.record_resource.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "KinesisApiGwIntegration" {
  rest_api_id          = aws_api_gateway_rest_api.kinesis-api-gw.id
  resource_id          = aws_api_gateway_resource.record_resource.id
  http_method          = aws_api_gateway_method.putRecord.http_method
  type                 = "AWS"
  integration_http_method = "POST"
  uri = "arn:aws:apigateway:ap-northeast-2:kinesis:action/PutRecord"
  credentials = aws_iam_role.api_gw_kinesis_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'x-amz-json-1.1'"
  }

  # Transforms the incoming XML request to JSON
  request_templates = {
    "application/x-amz-json-1.1" = <<EOF
{
    "StreamName": "$input.params('stream-name')",
    "Data": "$util.base64Encode($input.json('$.Data'))",
    "PartitionKey": "$input.path('$.PartitionKey')"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id          = aws_api_gateway_rest_api.kinesis-api-gw.id
  resource_id          = aws_api_gateway_resource.record_resource.id
  http_method          = aws_api_gateway_method.putRecord.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id          = aws_api_gateway_rest_api.kinesis-api-gw.id
  resource_id          = aws_api_gateway_resource.record_resource.id
  http_method          = aws_api_gateway_method.putRecord.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
}

resource "aws_api_gateway_deployment" "api-deployment" {
  rest_api_id = aws_api_gateway_rest_api.kinesis-api-gw.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.record_resource.id,
      aws_api_gateway_resource.stream_name_resource.id,
      aws_api_gateway_resource.streams_resource.id,
      aws_api_gateway_method.putRecord.id,
      aws_api_gateway_integration.KinesisApiGwIntegration.id
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "s1" {
  deployment_id = aws_api_gateway_deployment.api-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.kinesis-api-gw.id
  stage_name    = "s1"
}