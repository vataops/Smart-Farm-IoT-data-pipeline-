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
    "catalog-id" = "917517450640"
  }
}

resource "aws_athena_workgroup" "test" {
  name = "test-workgroup"
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