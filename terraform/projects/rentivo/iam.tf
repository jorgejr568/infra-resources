resource "aws_iam_user" "rentivo" {
  name = "rentivo"
  path = "/service/"
}

data "aws_iam_policy_document" "rentivo_files_rw" {
  statement {
    sid    = "ListRentivoFilesBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.rentivo_files.arn]
  }

  statement {
    sid    = "ReadWriteRentivoFilesObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.rentivo_files.arn}/*"]
  }
}

resource "aws_iam_policy" "rentivo_files_rw" {
  name        = "rentivo-files-rw"
  description = "Allows the rentivo service user to read and write objects in the rentivo-files bucket."
  policy      = data.aws_iam_policy_document.rentivo_files_rw.json
}

resource "aws_iam_user_policy_attachment" "rentivo_files_rw" {
  user       = aws_iam_user.rentivo.name
  policy_arn = aws_iam_policy.rentivo_files_rw.arn
}

data "aws_iam_policy_document" "rentivo_ses_send" {
  statement {
    sid    = "SendFromNaoresponder"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = [aws_ses_domain_identity.rentivo.arn]
    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [local.rentivo_from_sender]
    }
  }
}

resource "aws_iam_policy" "rentivo_ses_send" {
  name        = "rentivo-ses-send-naoresponder"
  description = "Allows the rentivo service user to send email via SES, only with From address ${local.rentivo_from_sender}."
  policy      = data.aws_iam_policy_document.rentivo_ses_send.json
}

resource "aws_iam_user_policy_attachment" "rentivo_ses_send" {
  user       = aws_iam_user.rentivo.name
  policy_arn = aws_iam_policy.rentivo_ses_send.arn
}

resource "aws_iam_access_key" "rentivo" {
  user = aws_iam_user.rentivo.name
}

output "rentivo_user_name" {
  description = "IAM user name for the rentivo service account."
  value       = aws_iam_user.rentivo.name
}

output "rentivo_access_key_id" {
  description = "Access key ID for the rentivo user."
  value       = aws_iam_access_key.rentivo.id
  sensitive   = true
}

output "rentivo_secret_access_key" {
  description = "Secret access key for the rentivo user."
  value       = aws_iam_access_key.rentivo.secret
  sensitive   = true
}
