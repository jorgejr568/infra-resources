resource "aws_s3_bucket" "hooks_fyi_request_files" {
  bucket = "hooks-fyi-request-files"
}

resource "aws_s3_bucket_public_access_block" "hooks_fyi_request_files" {
  bucket = aws_s3_bucket.hooks_fyi_request_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hooks_fyi_request_files" {
  bucket = aws_s3_bucket.hooks_fyi_request_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "hooks_fyi_request_files" {
  bucket = aws_s3_bucket.hooks_fyi_request_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "hooks_fyi_request_files" {
  bucket = aws_s3_bucket.hooks_fyi_request_files.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

output "hooks_fyi_request_files_bucket" {
  description = "Name of the request-files S3 bucket."
  value       = aws_s3_bucket.hooks_fyi_request_files.id
}

output "hooks_fyi_request_files_bucket_arn" {
  description = "ARN of the request-files S3 bucket."
  value       = aws_s3_bucket.hooks_fyi_request_files.arn
}
