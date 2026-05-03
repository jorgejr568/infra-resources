data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "rentivo_kms" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "rentivo" {
  description              = "Rentivo app encryption key"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  deletion_window_in_days  = 7
  policy                   = data.aws_iam_policy_document.rentivo_kms.json
}

resource "aws_kms_alias" "rentivo" {
  name          = "alias/rentivo"
  target_key_id = aws_kms_key.rentivo.key_id
}

data "aws_iam_policy_document" "rentivo_kms_use" {
  statement {
    sid    = "UseRentivoKey"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.rentivo.arn]
  }
}

resource "aws_iam_policy" "rentivo_kms_use" {
  name        = "rentivo-kms-use"
  description = "Allows the rentivo service user to encrypt/decrypt with the rentivo KMS key."
  policy      = data.aws_iam_policy_document.rentivo_kms_use.json
}

resource "aws_iam_user_policy_attachment" "rentivo_kms_use" {
  user       = aws_iam_user.rentivo.name
  policy_arn = aws_iam_policy.rentivo_kms_use.arn
}

output "rentivo_kms_key_id" {
  description = "ID of the rentivo KMS key."
  value       = aws_kms_key.rentivo.key_id
}

output "rentivo_kms_key_arn" {
  description = "ARN of the rentivo KMS key."
  value       = aws_kms_key.rentivo.arn
}

output "rentivo_kms_alias" {
  description = "Alias name for the rentivo KMS key."
  value       = aws_kms_alias.rentivo.name
}
