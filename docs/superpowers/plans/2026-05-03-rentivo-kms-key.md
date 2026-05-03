# Rentivo KMS Key Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a customer-managed AWS KMS key to the rentivo Terraform module so the rentivo IAM service user can perform Encrypt/Decrypt/GenerateDataKey operations.

**Architecture:** Single new file `terraform/projects/rentivo/kms.tf` defines the key, alias, key policy (account root only), an IAM policy granting key usage to the existing `aws_iam_user.rentivo`, and module-level outputs. The root `terraform/outputs.tf` re-exports the three outputs. No edits to existing rentivo files.

**Tech Stack:** Terraform `>= 1.10.0, < 2.0.0`, `hashicorp/aws ~> 6.0`, pre-commit (`terraform_fmt`, `terraform_validate`, `tflint`), Trivy config scan in CI.

**Spec:** [`docs/superpowers/specs/2026-05-03-rentivo-kms-key-design.md`](../specs/2026-05-03-rentivo-kms-key-design.md)

**Branch:** `feat/rentivo-kms-key` (already created and contains the spec commit).

---

## File map

| File | Change | Responsibility |
| --- | --- | --- |
| `terraform/projects/rentivo/kms.tf` | **Create** | Key, alias, key policy, IAM policy + attachment, module outputs |
| `terraform/outputs.tf` | **Modify** | Re-export `rentivo_kms_key_id`, `rentivo_kms_key_arn`, `rentivo_kms_alias` |

No other files are touched.

---

## Verification model

Terraform doesn't have unit tests; the equivalent loop is:

1. `terraform fmt -check -recursive` — formatting
2. `terraform init -backend=false && terraform validate` — schema/reference correctness
3. `tflint --recursive --format=compact` — lint
4. `terraform plan` (in CI, on PR) — actual diff verification

We treat **a clean `terraform validate`** as the unit-level pass and **the CI plan diff** as the integration-level pass.

All shell commands in this plan are run from `/Users/j/src/jorgejr568/infra-resources/terraform` unless noted.

---

## Task 1: Create `kms.tf` with all KMS + IAM resources and module outputs

**Files:**
- Create: `terraform/projects/rentivo/kms.tf`

The whole file lands in one commit because Terraform validates as a whole module — splitting outputs from their resources or IAM attachments from their policies would leave intermediate states that don't round-trip cleanly through `terraform validate`.

- [ ] **Step 1: Write `terraform/projects/rentivo/kms.tf`**

Exact contents:

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
```

Notes for the engineer:
- `aws_iam_user.rentivo` is already declared in `terraform/projects/rentivo/iam.tf:1-4` — we reference it directly, no `data` lookup needed.
- The provider alias `aws.rentivo` is already wired in `terraform/main.tf:13-23`, so no provider block is needed inside `kms.tf`.
- The repo's existing IAM policies in `iam.tf` use `aws_iam_policy_document` data sources; we follow the same pattern for consistency.

- [ ] **Step 2: Format**

Run from `terraform/`:

```bash
terraform fmt -recursive
```

Expected: no output (or `projects/rentivo/kms.tf` reformatted in place if your editor produced odd whitespace).

- [ ] **Step 3: Validate**

Run from `terraform/`:

```bash
terraform init -backend=false && terraform validate
```

Expected: `Success! The configuration is valid.`

If validate fails with "Reference to undeclared resource: aws_iam_user.rentivo", check that you placed the file inside `terraform/projects/rentivo/` (same directory as `iam.tf`).

- [ ] **Step 4: Commit**

```bash
git add terraform/projects/rentivo/kms.tf
git commit -m "$(cat <<'EOF'
feat(tf): add rentivo KMS key for app encryption

Customer-managed symmetric KMS key (alias/rentivo) with rotation
enabled and a 7-day deletion window. Account root holds the key
policy; the rentivo IAM service user receives Encrypt, Decrypt,
ReEncrypt*, GenerateDataKey*, and DescribeKey via an attached IAM
policy scoped to the key ARN.
EOF
)"
```

Pre-commit will run `terraform_fmt`, `terraform_validate`, and `tflint`. If pre-commit reports a tflint finding, fix the file and create a **new** commit (do not amend).

---

## Task 2: Re-export outputs at the root

**Files:**
- Modify: `terraform/outputs.tf`

The root `outputs.tf` exposes module outputs to operators and to the CI plan diff. Three new outputs forward what the rentivo module exports.

- [ ] **Step 1: Add three outputs to `terraform/outputs.tf`**

Append at the end of the file (after the last existing output, currently `joy_living_zone_id` at line ~96):

```hcl

output "rentivo_kms_key_id" {
  description = "ID of the rentivo KMS key."
  value       = module.rentivo.rentivo_kms_key_id
}

output "rentivo_kms_key_arn" {
  description = "ARN of the rentivo KMS key."
  value       = module.rentivo.rentivo_kms_key_arn
}

output "rentivo_kms_alias" {
  description = "Alias of the rentivo KMS key."
  value       = module.rentivo.rentivo_kms_alias
}
```

(The leading blank line keeps the existing inter-output spacing.)

- [ ] **Step 2: Format**

```bash
terraform fmt -recursive
```

Expected: no output.

- [ ] **Step 3: Validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

If validate complains "module.rentivo does not have output rentivo_kms_key_id", Task 1's outputs were not committed — verify with `grep 'output "rentivo_kms' projects/rentivo/kms.tf` and re-run.

- [ ] **Step 4: Commit**

```bash
git add terraform/outputs.tf
git commit -m "$(cat <<'EOF'
feat(tf): expose rentivo KMS outputs at the root

Re-export rentivo_kms_key_id, rentivo_kms_key_arn, and
rentivo_kms_alias from the rentivo module so they appear in
terraform output and the CI plan summary.
EOF
)"
```

---

## Task 3: Lint and Trivy sanity check

**Files:** none modified unless a finding requires it.

- [ ] **Step 1: Run tflint across the whole tree**

```bash
tflint --recursive --format=compact
```

Expected: no findings, exit code 0.

If a finding appears, decide:
- Genuine fix → edit the file, re-run, commit as `fix(tf): ...`
- Deliberate choice → add a one-line entry with `# why:` to `.tflint.hcl` per `CONTRIBUTING.md` and commit as `chore(tf): suppress tflint <rule>`.

- [ ] **Step 2: Run Trivy config scan locally (optional but cheaper than waiting for CI)**

If `trivy` is on PATH:

```bash
trivy config --exit-code 0 .
```

Expected behavior:
- KMS key with rotation enabled should not flag `AVD-AWS-0066`.
- If a finding appears, decide fix vs. `.trivyignore` entry (per `CONTRIBUTING.md`'s "Plan rules of thumb"), and commit accordingly.

If `trivy` is not installed, skip — CI will run it.

- [ ] **Step 3: No-op if no findings**

If neither tool produced findings, no commit is needed for this task. Move on.

---

## Task 4: Push branch, open PR, verify CI plan diff

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/rentivo-kms-key
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --base main --title "feat(tf): add rentivo KMS key for app encryption" --body "$(cat <<'EOF'
## Summary

- Add customer-managed symmetric KMS key `alias/rentivo` with rotation enabled and a 7-day deletion window
- Grant the existing `rentivo` IAM service user `kms:Encrypt`, `kms:Decrypt`, `kms:ReEncrypt*`, `kms:GenerateDataKey*`, `kms:DescribeKey` scoped to the new key
- Re-export `rentivo_kms_key_id`, `rentivo_kms_key_arn`, `rentivo_kms_alias` at the root module

Spec: `docs/superpowers/specs/2026-05-03-rentivo-kms-key-design.md`

## Expected plan diff (additions only — no modifications, no destroys)

- `module.rentivo.aws_kms_key.rentivo` — created
- `module.rentivo.aws_kms_alias.rentivo` — created
- `module.rentivo.aws_iam_policy.rentivo_kms_use` — created
- `module.rentivo.aws_iam_user_policy_attachment.rentivo_kms_use` — created
- `module.rentivo.data.aws_caller_identity.current` — read
- `module.rentivo.data.aws_iam_policy_document.{rentivo_kms,rentivo_kms_use}` — read
- Three new root outputs

## Test plan

- [ ] `pr-checks.yml` workflow passes (`terraform-plan`, `tflint`, `trivy-config`)
- [ ] Plan comment shows additions only — no `~` modifications, no `-` destroys, no drift on the existing rentivo S3 / IAM / SES resources
- [ ] After merge, `terraform-apply.yml` succeeds and the key + alias appear in the AWS console

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Capture the printed PR URL.

- [ ] **Step 3: Wait for CI and inspect the plan comment**

```bash
gh pr checks --watch
```

When `terraform-plan` finishes, read the bot comment:

```bash
gh pr view --comments
```

Verify the plan output:
- Resources to add: **4** (kms_key, kms_alias, iam_policy, iam_user_policy_attachment)
- Resources to change: **0**
- Resources to destroy: **0**
- New outputs: 3 (`rentivo_kms_key_id`, `rentivo_kms_key_arn`, `rentivo_kms_alias`)

If anything other than additions appears, **stop** and ask the human partner — that means an existing resource is being touched unexpectedly.

- [ ] **Step 4: Hand off**

Once the plan diff is verified clean, the PR is ready for the maintainer to review and merge. The merge triggers `terraform-apply.yml`, which materializes the key.

---

## Done criteria

- `feat/rentivo-kms-key` branch contains: spec commit (already there), Task 1 commit, Task 2 commit, optional Task 3 commit(s).
- PR is open against `main`.
- `pr-checks.yml` is green.
- Plan diff is additions-only and matches the expected resource list.
