# S3 bucket for logs + CloudTrail.

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV_AWS_144: Cross-region replication is out of scope/cost for this project
  # checkov:skip=CKV_AWS_145: SSE-S3 (AES-256) is enabled below; a KMS CMK adds monthly cost without benefit at this scale
  # checkov:skip=CKV2_AWS_62: Event notifications are not needed for a write-only audit-log bucket
  # checkov:skip=CKV_AWS_18: This IS the log bucket; access-logging it to itself would recurse
  bucket        = "${var.project_name}-logs-${random_id.suffix.hex}"
  force_destroy = true # so terraform destroy can remove it even if not empty
  tags          = { Name = "${var.project_name}-logs" }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# expire logs after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

# deny non-TLS access + let CloudTrail write here
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

# using SSE-S3 instead of a KMS key to avoid extra cost (see checkov:skip below)
resource "aws_cloudtrail" "main" { # nosemgrep: terraform.aws.security.aws-cloudtrail-encrypted-with-cmk.aws-cloudtrail-encrypted-with-cmk
  # checkov:skip=CKV_AWS_252: SNS notifications for log delivery are out of scope for this project
  # checkov:skip=CKV_AWS_35: Logs are encrypted with SSE-S3; a KMS CMK adds monthly cost without benefit at this scale
  # checkov:skip=CKV2_AWS_10: S3 delivery with log-file validation is sufficient here; CloudWatch integration adds cost/complexity
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.logs]
  tags                          = { Name = "${var.project_name}-trail" }
}
