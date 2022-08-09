resource "aws_s3_bucket" "tf-dummy" {
  bucket = "tf-sensor-data-bucket"
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

resource "aws_iam_role" "AWSGlueRole-parquet-data-crawler" {
  name = "AWSGlueRoleParquetDataCrawler"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Principal": {
            "Service": "glue.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy" "AWSGlueServiceRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "AWSGlueRolePolicyAttachment" {
  role       = "${aws_iam_role.AWSGlueRole-parquet-data-crawler.name}"
  policy_arn = "${data.aws_iam_policy.AWSGlueServiceRole.arn}"
}

resource "aws_iam_role_policy" "AWSGlueRoleParquetDataCrawlerPolicy" {
  name   = "AWSGlueRoleParquetDataCrawlerPolicy"
  role   = "${aws_iam_role.AWSGlueRole-parquet-data-crawler.name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "s3:GetObject",
            "s3:PutObject"
        ],
        "Resource": [
            "${aws_s3_bucket.tf-dummy.arn}/*"
        ]
      }
  ]
}
EOF
}


resource "aws_glue_crawler" "example" {
  database_name = aws_glue_catalog_database.tf-sensor-database.name
  name          = "parquet-sensor-data-crawler"
  role          = aws_iam_role.AWSGlueRole-parquet-data-crawler.arn
  # schedule      = "cron(0/15 * * * ? *)"
  s3_target {
    path = "s3://${aws_s3_bucket.tf-dummy.bucket}"
  }
}