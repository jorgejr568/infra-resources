resource "aws_iam_user" "hooks_fyi" {
  name = "hooks-fyi"
  path = "/service/"
}

data "aws_iam_policy_document" "hooks_fyi_request_files_rw" {
  statement {
    sid    = "ListRequestFilesBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.hooks_fyi_request_files.arn]
  }

  statement {
    sid    = "ReadWriteRequestFilesObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.hooks_fyi_request_files.arn}/*"]
  }
}

resource "aws_iam_policy" "hooks_fyi_request_files_rw" {
  name        = "hooks-fyi-request-files-rw"
  description = "Allows the hooks-fyi service user to read and write objects in the hooks-fyi-request-files bucket."
  policy      = data.aws_iam_policy_document.hooks_fyi_request_files_rw.json
}

resource "aws_iam_user_policy_attachment" "hooks_fyi_request_files_rw" {
  user       = aws_iam_user.hooks_fyi.name
  policy_arn = aws_iam_policy.hooks_fyi_request_files_rw.arn
}

resource "aws_iam_access_key" "hooks_fyi" {
  user = aws_iam_user.hooks_fyi.name
}

output "hooks_fyi_user_name" {
  description = "IAM user name for the hooks-fyi service account."
  value       = aws_iam_user.hooks_fyi.name
}

output "hooks_fyi_access_key_id" {
  description = "Access key ID for the hooks-fyi user. Store in your application's secret manager."
  value       = aws_iam_access_key.hooks_fyi.id
  sensitive   = true
}

output "hooks_fyi_secret_access_key" {
  description = "Secret access key for the hooks-fyi user. Store in your application's secret manager. Only readable from terraform state."
  value       = aws_iam_access_key.hooks_fyi.secret
  sensitive   = true
}
