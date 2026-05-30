# Private application bucket.
resource "aws_s3_bucket" "eic_seminarios" {
  bucket = "eic-seminarios"
}

resource "aws_s3_bucket_versioning" "eic_seminarios" {
  bucket = aws_s3_bucket.eic_seminarios.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "eic_seminarios" {
  bucket = aws_s3_bucket.eic_seminarios.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "eic_seminarios" {
  bucket = aws_s3_bucket.eic_seminarios.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "eic_seminarios" {
  bucket = aws_s3_bucket.eic_seminarios.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Public static-website bucket for the guide site (fronted by CloudFront).
resource "aws_s3_bucket" "guide" {
  bucket = "guide.eic-seminarios.com"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "guide" {
  bucket = aws_s3_bucket.guide.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_ownership_controls" "guide" {
  bucket = aws_s3_bucket.guide.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Intentionally permissive: this is a public website origin.
resource "aws_s3_bucket_public_access_block" "guide" {
  bucket = aws_s3_bucket.guide.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "guide" {
  bucket = aws_s3_bucket.guide.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

data "aws_iam_policy_document" "guide_public_read" {
  statement {
    sid     = "PublicReadGetObject"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    # Literal ARN (not a reference to aws_s3_bucket.guide) so the document
    # resolves at plan time and the imported policy shows no spurious diff.
    resources = ["arn:aws:s3:::guide.eic-seminarios.com/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "guide" {
  bucket = aws_s3_bucket.guide.id
  policy = data.aws_iam_policy_document.guide_public_read.json
}

output "eic_seminarios_bucket" {
  description = "Name of the private eic-seminarios application bucket."
  value       = aws_s3_bucket.eic_seminarios.id
}

output "guide_bucket" {
  description = "Name of the public guide static-website bucket."
  value       = aws_s3_bucket.guide.id
}
