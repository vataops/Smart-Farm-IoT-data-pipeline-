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

resource "aws_s3_bucket" "athena-query-archive" {
  bucket = "tf-athena-query-archive-bucket"
  force_destroy = true
  tags = {
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_acl" "athena-query-arhive-bucket-acl" {
  bucket = aws_s3_bucket.athena-query-archive.id
  acl    = "private"
}

resource "aws_athena_data_catalog" "tf-sensor-data-catalog" {
  name        = "glue-data-catalog"
  description = "Glue based Data Catalog"
  type        = "GLUE"

  parameters = {
    "catalog-id" = var.account_id
  }
}

resource "aws_athena_workgroup" "test" {
  name = "test-workgroup"
  force_destroy = true
}

# resource "aws_athena_database" "tf-sensor-database" {
#   name   = "${aws_glue_catalog_database.tf-sensor-database.name}"
#   bucket = aws_s3_bucket.tf-dummy.id
# }

resource "aws_athena_named_query" "test-query" {
  name      = "test-query"
  workgroup = aws_athena_workgroup.test.id
  database  = aws_glue_catalog_database.tf-sensor-database.name
  query     = "SELECT * FROM ${aws_glue_catalog_database.tf-sensor-database.name} limit 10;"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "172.16.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "tf-example"
  }
}

resource "aws_internet_gateway" "my_vpc_gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "tf-example"
  }
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_vpc_gw.id
  }

  tags = {
    Name = "example"
  }
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.my_vpc.id
  route_table_id = aws_route_table.example.id
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "tf-example"
  }
}

resource "aws_security_group" "allow_grafana" {
  name        = "Grafana-SecGp"
  description = "Allow inbound grafana traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description      = "Grafana traffic (3000) from VPC"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_grafana"
  }
}

resource "aws_instance" "grafana-ec2-final" {
  ami           = "ami-058165de3b7202099" # ap-northeast-2 Ubuntu 22.04 (LTS)
  instance_type = "t2.nano"
  subnet_id = aws_subnet.my_subnet.id
  key_name = "ubuntu-key"

  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.allow_grafana.id]

  user_data = <<EOF
#!/bin/bash
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server
sudo systemctl enable grafana-server.service
EOF

  tags = {
    Name = "grafana-ec2-final"
  }
}


data "aws_route53_zone" "hosted-zone" {
  name         = "${var.domain_name}"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.hosted-zone.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.grafana-ec2-final.public_ip}"]
}