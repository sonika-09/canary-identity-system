data "aws_caller_identity" "current" {}

# S3 bucket for CloudTrail log storage
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "canary-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AllowCloudTrailWriteObjects"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudWatch Logs log group for CloudTrail delivery
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/canary"
  retention_in_days = 30
}

# CloudTrail IAM role for CloudWatch Logs delivery
resource "aws_iam_role" "cloudtrail_cwl_role" {
  name = "cloudtrail-cwl-delivery-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cwl_policy" {
  name = "cloudtrail-cwl-delivery-policy"
  role = aws_iam_role.cloudtrail_cwl_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# CloudTrail
resource "aws_cloudtrail" "canary_trail" {
  name                          = "canary-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_role_arn      = aws_iam_role.cloudtrail_cwl_role.arn
  cloud_watch_logs_log_group_arn = aws_cloudwatch_log_group.cloudtrail.arn

  event_selectors {
    read_write_type           = "All"
    include_management_events = true

    data_resources {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/"]
    }
  }
}
