# 아키텍쳐에서 Kinesis 포션을 생성하기 위한 .tf 스크립트입니다.
terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 1.2.0"
}

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
        "arn:aws:s3:::coz-farm-sensor-data-bucket",
        "arn:aws:s3:::coz-farm-sensor-data-bucket/*"
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
        "arn:aws:glue:ap-northeast-2:917517450640:catalog",
        "arn:aws:glue:ap-northeast-2:917517450640:database/farm_sensor_database",
        "arn:aws:glue:ap-northeast-2:917517450640:table/farm_sensor_database/test_bucket_crawler_1324"
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
    role_arn = "arn:aws:iam::917517450640:role/firehose_test_role"
  }
  extended_s3_configuration {
    role_arn   = "arn:aws:iam::917517450640:role/firehose_test_role"
    bucket_arn = "arn:aws:s3:::coz-farm-sensor-data-bucket"
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
        database_name = "farm_sensor_database"
        role_arn      = "arn:aws:iam::917517450640:role/firehose_test_role"
        table_name    = "test_bucket_crawler_1324"
      }
    }
  }
}