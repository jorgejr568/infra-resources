resource "aws_s3_bucket" "rentivo_files" {
  bucket = "rentivo-files"
}

resource "aws_s3_bucket_public_access_block" "rentivo_files" {
  bucket = aws_s3_bucket.rentivo_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rentivo_files" {
  bucket = aws_s3_bucket.rentivo_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "rentivo_files" {
  bucket = aws_s3_bucket.rentivo_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "rentivo_files" {
  bucket = aws_s3_bucket.rentivo_files.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

output "rentivo_files_bucket" {
  description = "Name of the rentivo-files S3 bucket."
  value       = aws_s3_bucket.rentivo_files.id
}

output "rentivo_files_bucket_arn" {
  description = "ARN of the rentivo-files S3 bucket."
  value       = aws_s3_bucket.rentivo_files.arn
}
