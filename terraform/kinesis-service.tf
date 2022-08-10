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

# 아키텍쳐에서 Kinesis 포션을 생성하기 위한 .tf 스크립트입니다.
// 센서 데이터 수집을 위한 Kinesis Data Stream
resource "aws_kinesis_stream" "test_stream" {
  name             = "tf-test-stream"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Environment = "test"
  }
}

// Kinesis Firehose (Delivery Stream)의 정상 작동을 위한 Role 생성
resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

// Kinesis Firehose Role에 부여할 Policy 생성
// * 추후 추가적인 리소스를 생성했을때 이를 참조 할 수 있도록 수정
resource "aws_iam_role_policy" "inline-policy" {
  name   = "firehose_inline_policy"
  role   = "${aws_iam_role.firehose_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.tf-dummy.arn}",
        "${aws_s3_bucket.tf-dummy.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords"
      ],
      "Resource": "${aws_kinesis_stream.test_stream.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetTable",
        "glue:GetTableVersion",
        "glue:GetTableVersions"
      ],
      "Resource": [
        "arn:aws:glue:ap-northeast-2:${var.account_id}:catalog",
        "${aws_glue_catalog_database.tf-sensor-database.arn}",
        "${aws_glue_catalog_table.tf-sensor-primer-table.arn}"
      ]
    }
  ]
}
EOF
}

// Kinesis Data Streams를 통해 유입되는 데이터에 대한 ETL 프로세스를 도와주는 Firehose 생성
resource "aws_kinesis_firehose_delivery_stream" "test_delivery_stream" {
  # ... other configuration ...
  name = "test-delivery-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.test_stream.arn
    role_arn = aws_iam_role.firehose_role.arn
  }
  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.tf-dummy.arn
    # Must be at least 64
    buffer_size = 128
    buffer_interval = 60
    # ... other configuration ...
    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = aws_glue_catalog_database.tf-sensor-database.name
        role_arn      = aws_iam_role.firehose_role.arn
        table_name    = aws_glue_catalog_table.tf-sensor-primer-table.name
      }
    }
  }
}

resource "aws_s3_bucket" "tf-dummy" {
  bucket = "sensor-log-bucket"
  force_destroy = true
  tags = {
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.tf-dummy.id
  acl    = "private"
}

resource "aws_glue_catalog_database" "tf-sensor-database" {
  name = "tf_sensor_database"
}

resource "aws_glue_catalog_table" "tf-sensor-primer-table" {
  name          = "tf-sensor-data-table"
  database_name = aws_glue_catalog_database.tf-sensor-database.name

  parameters = {
    "classification" = "json"
  }

  storage_descriptor {
    location      = aws_s3_bucket.tf-dummy.bucket
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    parameters = {
      "classification" = "json"
    }

    ser_de_info {
      name                  = "my-stream"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "result"
      type = "string"
    }

    columns {
      name = "error_code"
      type = "string"
    }

    columns {
      name    = "device_id"
      type    = "string"
    }

    columns {
      name    = "coord"
      type    = "struct<lon:string,lat:string>"
    }
    columns {
      name    = "server_time"
      type    = "timestamp"
    }
    columns {
      name    = "temperature"
      type    = "int"
    }
    columns {
      name    = "pressure"
      type    = "int"
    }
    columns {
      name    = "humidity"
      type    = "int"
    }
    columns {
      name    = "co2"
      type    = "int"
    }
    
  }
}