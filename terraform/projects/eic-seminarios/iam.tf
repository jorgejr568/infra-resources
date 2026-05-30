# Main application service user: SES send (restricted senders), S3 rw on the
# app bucket, and CloudWatch Logs for the seminarios-eic log group.
resource "aws_iam_user" "eic_seminarios" {
  name = "eic-seminarios"
  path = "/"
}

# Policy documents use literal ARNs (not resource references) so they resolve
# at plan time and the imported policies show no spurious diff while the
# referenced buckets/distribution pick up default tags on first apply.
data "aws_iam_policy_document" "eic_seminarios_ses" {
  statement {
    effect    = "Allow"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["no-reply@eic-seminarios.com", "naoresponder@eic-seminarios.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::eic-seminarios",
      "arn:aws:s3:::eic-seminarios/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups", "logs:DescribeLogStreams"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:seminarios-eic",
      "arn:aws:logs:*:*:log-group:seminarios-eic:*",
    ]
  }
}

resource "aws_iam_policy" "eic_seminarios_ses" {
  name   = "eic-seminarios-ses"
  policy = data.aws_iam_policy_document.eic_seminarios_ses.json
}

resource "aws_iam_user_policy_attachment" "eic_seminarios_ses" {
  user       = aws_iam_user.eic_seminarios.name
  policy_arn = aws_iam_policy.eic_seminarios_ses.arn
}

# Two existing access keys, imported. AWS never returns a key's secret on
# import, so the secret for the 2024-10 key was injected into state manually
# (the value the operator still held); it is surfaced via the outputs below.
resource "aws_iam_access_key" "eic_seminarios" {
  for_each = toset(["2026-01", "2024-10"])
  user     = aws_iam_user.eic_seminarios.name
}

output "eic_seminarios_access_key_id" {
  description = "Access key ID for the eic-seminarios service user (the 2024-10 key)."
  value       = aws_iam_access_key.eic_seminarios["2024-10"].id
  sensitive   = true
}

output "eic_seminarios_access_key_secret" {
  description = "Secret access key for the eic-seminarios service user (2024-10 key). Injected into state from the operator-held value; readable from state only."
  value       = aws_iam_access_key.eic_seminarios["2024-10"].secret
  sensitive   = true
}

# Guide deploy user: write to the guide bucket + invalidate the CloudFront dist.
resource "aws_iam_user" "guide_uploader" {
  name = "eic-seminarios-guide-uploader"
  path = "/"
}

data "aws_iam_policy_document" "guide_sync" {
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::guide.eic-seminarios.com",
      "arn:aws:s3:::guide.eic-seminarios.com/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["arn:aws:cloudfront::730335335283:distribution/E34WTTE9HV683E"]
  }
}

resource "aws_iam_user_policy" "guide_sync" {
  name   = "S3GuideSync"
  user   = aws_iam_user.guide_uploader.name
  policy = data.aws_iam_policy_document.guide_sync.json
}

# Fresh key (old secret was lost). Update the guide deploy with these, then
# delete the old key AKIA2UC3A2NZ3WOIMLGE (post-apply follow-up).
resource "aws_iam_access_key" "guide_uploader" {
  user = aws_iam_user.guide_uploader.name
}

output "guide_uploader_access_key_id" {
  description = "Access key ID for the new guide-uploader key. Configure in the guide deploy."
  value       = aws_iam_access_key.guide_uploader.id
  sensitive   = true
}

output "guide_uploader_secret_access_key" {
  description = "Secret for the new guide-uploader key. Readable from state only; configure in the guide deploy, then delete the old key."
  value       = aws_iam_access_key.guide_uploader.secret
  sensitive   = true
}
