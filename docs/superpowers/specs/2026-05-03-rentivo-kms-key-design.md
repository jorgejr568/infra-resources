# Rentivo KMS Key — Design

**Date:** 2026-05-03
**Project:** `terraform/projects/rentivo/`
**Status:** Approved

## Goal

Provision a customer-managed AWS KMS key dedicated to the `rentivo` project so the rentivo application can perform generic encryption and decryption operations (Encrypt, Decrypt, GenerateDataKey, etc.) using its existing IAM service user credentials.

## Non-goals

- **Not** changing S3 bucket-level encryption. The `rentivo-files` bucket stays on AES256 SSE. Migrating to SSE-KMS is a separate, future change.
- **Not** integrating with SES, RDS, Secrets Manager, or any other AWS service in this iteration.
- **Not** introducing multi-region keys. Single-region (`us-east-1`) matches the rest of the rentivo footprint.
- **Not** creating cross-account access. Only the local AWS account principals consume the key.

## Resources

All new resources live in a new file `terraform/projects/rentivo/kms.tf`. No existing files in the rentivo module are modified except as noted under "Outputs."

### `aws_kms_key.rentivo`

| Attribute | Value |
| --- | --- |
| `description` | `Rentivo app encryption key` |
| `key_usage` | `ENCRYPT_DECRYPT` (default; explicit for clarity) |
| `customer_master_key_spec` | `SYMMETRIC_DEFAULT` (default; explicit for clarity) |
| `enable_key_rotation` | `true` |
| `deletion_window_in_days` | `7` |
| `policy` | See "Key policy" below |

### `aws_kms_alias.rentivo`

| Attribute | Value |
| --- | --- |
| `name` | `alias/rentivo` |
| `target_key_id` | `aws_kms_key.rentivo.key_id` |

### `aws_iam_policy.rentivo_kms_use`

Customer-managed IAM policy attached to the existing `aws_iam_user.rentivo` (defined in `iam.tf`). Granted actions, scoped to the key ARN only:

- `kms:Encrypt`
- `kms:Decrypt`
- `kms:ReEncrypt*`
- `kms:GenerateDataKey*`
- `kms:DescribeKey`

Constructed via an `aws_iam_policy_document` data source for consistency with the existing `rentivo_files_rw` and `rentivo_ses_send` policies.

### `aws_iam_user_policy_attachment.rentivo_kms_use`

Attaches `aws_iam_policy.rentivo_kms_use` to `aws_iam_user.rentivo`.

## Key policy

Standard AWS baseline: the account root gets full administrative permission, which delegates further access decisions to IAM policies. This matches AWS guidance for customer-managed keys whose grants are managed via IAM rather than inline key policies.

```hcl
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
```

The rentivo user gains usage permissions through the attached `rentivo_kms_use` IAM policy — no inline key-policy statement for that user. This keeps the key policy minimal and lets IAM be the single source of truth for who can call the key.

## Outputs

### Module-level (`terraform/projects/rentivo/kms.tf`)

- `rentivo_kms_key_id` — `aws_kms_key.rentivo.key_id`
- `rentivo_kms_key_arn` — `aws_kms_key.rentivo.arn`
- `rentivo_kms_alias` — `aws_kms_alias.rentivo.name`

### Root-level (`terraform/outputs.tf`)

Same three outputs re-exported from the `module.rentivo` block, matching the existing pattern (e.g., `rentivo_files_bucket`, `rentivo_user_name`).

## Files touched

| File | Change |
| --- | --- |
| `terraform/projects/rentivo/kms.tf` | **New.** All KMS resources, IAM policy + attachment, module-level outputs. |
| `terraform/outputs.tf` | **Modified.** Add three root-level outputs forwarding the module outputs. |

No edits to `s3.tf`, `iam.tf`, `ses.tf`, `cloudflare.tf`, `variables.tf`, `versions.tf`, `main.tf`, `providers.tf`, or `backend.tf`. The provider alias `aws.rentivo` is already wired through `main.tf`.

## Verification

Run from the `terraform/` directory before opening the PR:

```bash
terraform fmt -recursive
terraform init -backend=false && terraform validate
tflint --recursive --format=compact
```

Pre-commit will rerun the same set on commit.

The `terraform-plan` GitHub workflow will comment a plan diff on the PR. Expected diff: **additions only** — one `aws_kms_key`, one `aws_kms_alias`, one `aws_iam_policy`, one `aws_iam_user_policy_attachment`. No modifications, no destroys.

Trivy may flag the symmetric KMS key for `AVD-AWS-0066` (KMS auto-rotation) — already enabled. If Trivy raises any other finding the project considers acceptable, suppress in `.trivyignore` with a one-line `# why:` comment per the project's existing convention (`CONTRIBUTING.md`).

## Branch and commit

- Branch off `main`: `feat/rentivo-kms-key`.
- Commit message (Conventional Commits): `feat(tf): add rentivo KMS key for app encryption`.
- PR title mirrors the commit; PR body describes the expected plan diff per `CONTRIBUTING.md`'s "Plan rules of thumb."

## Risks / open questions

- **Key deletion window** is 7 days, the AWS minimum. Rationale: this key is not yet load-bearing; widening the window can come if the key starts protecting durable data. The window is a per-deletion-request setting and can be increased without recreating the key.
- **No grants resource.** If a downstream consumer (e.g., a future Lambda role) needs key access, prefer adding to the `rentivo_kms_use` IAM policy or a separate IAM policy rather than `aws_kms_grant`, to keep access discoverable in IAM.
- **Encryption context.** Not enforced at the key-policy level. The application is free to use encryption context for additional integrity, but the policy doesn't require it. If a future regulatory requirement mandates context, that's an additive policy change.
