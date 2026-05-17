# aws-resources Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a private GitHub Terraform repo `aws-resources` that manages AWS resources via GitHub Actions CI/CD, starting with one S3 bucket (`hooks-fyi-request-files`) and one IAM user (`hooks-fyi`) scoped to write to that bucket.

**Architecture:** Single Terraform root module under `terraform/` using the AWS provider with an S3 + DynamoDB remote state backend. Two GitHub Actions workflows (`plan` on PRs, `apply` on `main` push and manual dispatch) authenticate to AWS via long-lived access keys stored as repo secrets. A one-time bash script bootstraps the state bucket and lock table before CI is allowed to apply. Future improvements (OIDC auth, multi-env, modules) are out of scope.

**Tech Stack:** Terraform `>= 1.7`, AWS provider `~> 5.0`, GitHub Actions (`hashicorp/setup-terraform@v3`, `aws-actions/configure-aws-credentials@v4`), `gh` CLI for repo creation. AWS region: `us-east-1`.

**Notes for the executor:**
- Terraform is not installed locally and the user's current AWS credentials belong to a different account. **Do not run `terraform init/plan/apply` or any `aws` command** during execution — verification happens in CI on first push.
- If `terraform` is available (`brew install terraform`), running `terraform fmt -check -recursive` and `terraform validate` (after `terraform init -backend=false`) is encouraged but optional. CI will catch issues either way.
- For Terraform/infra code there is no traditional TDD loop. The "test" for each task is `terraform fmt -check` + `terraform validate` (locally if possible, otherwise CI). Workflow YAML changes are validated by `actionlint` if available, otherwise by GitHub Actions on push.
- Commit after each task, on the default branch `main`. The repo is created and pushed at the end (Task 10).

---

## File Structure

```
aws-resources/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml       # PR: fmt, validate, plan, comment
│       └── terraform-apply.yml      # main push + manual: apply
├── scripts/
│   └── bootstrap-backend.sh         # one-time: create state bucket + lock table
├── terraform/
│   ├── versions.tf                  # required_version + required_providers
│   ├── providers.tf                 # aws provider config
│   ├── backend.tf                   # S3 remote state
│   ├── variables.tf                 # region, tags
│   ├── outputs.tf                   # bucket + IAM outputs
│   ├── s3.tf                        # hooks-fyi-request-files bucket + hardening
│   └── iam.tf                       # hooks-fyi user + policy + access key
├── docs/
│   ├── ARCHITECTURE.md              # repo layout, state, auth, flows
│   └── superpowers/plans/2026-04-29-aws-resources-bootstrap.md  # this plan
├── .gitignore
├── .tool-versions                   # asdf/tfenv hint
└── README.md
```

Each file has one responsibility. `s3.tf` and `iam.tf` are split by resource family so adding more buckets/users later doesn't bloat a single file.

---

## Task 1: Repo skeleton (gitignore, tool-versions, README stub)

**Files:**
- Create: `<repo-root>/.gitignore`
- Create: `<repo-root>/.tool-versions`
- Create: `<repo-root>/README.md`

- [ ] **Step 1: Initialize git**

```bash
cd <repo-root>
git init -b main
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
# Terraform
**/.terraform/
**/.terraform.lock.hcl.bak
*.tfstate
*.tfstate.*
*.tfstate.backup
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
*.tfvars
*.tfvars.json
!example.tfvars

# Editor / OS
.DS_Store
.idea/
.vscode/
*.swp
```

> Note: we **do** commit `.terraform.lock.hcl` (provider version pinning).

- [ ] **Step 3: Write `.tool-versions`**

```
terraform 1.9.8
```

- [ ] **Step 4: Write README stub**

```markdown
# aws-resources

Terraform-managed AWS resources for the `hooks-fyi` ecosystem and beyond, applied via GitHub Actions.

> Full documentation lives in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). This README is a quick-start.

## Quick start

1. **Bootstrap the state backend (one-time, per AWS account):**
   ```bash
   ./scripts/bootstrap-backend.sh
   ```
2. **Configure GitHub secrets** on this repo:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. **Push to `main`** — the apply workflow will run automatically.
4. **For changes thereafter**, open a PR. The plan workflow comments the diff. Merge to apply.

## Layout

- `terraform/` — root Terraform module (all current resources).
- `.github/workflows/` — CI/CD (`terraform-plan.yml` for PRs, `terraform-apply.yml` for `main`).
- `scripts/` — one-off operational scripts (state backend bootstrap).
- `docs/` — architecture and decision docs.
```

- [ ] **Step 5: Verify and commit**

```bash
cd <repo-root>
ls -la
git add .gitignore .tool-versions README.md
git commit -m "chore: initial repo skeleton"
```
Expected: clean commit, working tree clean.

---

## Task 2: Terraform skeleton (versions, provider, backend, variables, outputs)

**Files:**
- Create: `terraform/versions.tf`
- Create: `terraform/providers.tf`
- Create: `terraform/backend.tf`
- Create: `terraform/variables.tf`
- Create: `terraform/outputs.tf`

- [ ] **Step 1: Write `terraform/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
```

- [ ] **Step 2: Write `terraform/providers.tf`**

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
      Project   = "hooks-fyi"
    }
  }
}
```

- [ ] **Step 3: Write `terraform/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "hooks-fyi-tfstate"
    key            = "aws-resources/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hooks-fyi-tflock"
    encrypt        = true
  }
}
```

> Backend block does not support variables. Bucket and table names must match `scripts/bootstrap-backend.sh` exactly. If `hooks-fyi-tfstate` is taken globally, change here and in the script consistently.

- [ ] **Step 4: Write `terraform/variables.tf`**

```hcl
variable "aws_region" {
  description = "AWS region for all resources in this configuration."
  type        = string
  default     = "us-east-1"
}
```

- [ ] **Step 5: Write `terraform/outputs.tf` (empty for now, populated in later tasks)**

```hcl
# Outputs are defined alongside their resources in s3.tf / iam.tf.
# This file is reserved for cross-cutting outputs.
```

- [ ] **Step 6: Verify**

If terraform is installed:
```bash
cd <repo-root>/terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```
Expected: `Success! The configuration is valid.`

If not installed: skip — CI will validate.

- [ ] **Step 7: Commit**

```bash
cd <repo-root>
git add terraform/versions.tf terraform/providers.tf terraform/backend.tf terraform/variables.tf terraform/outputs.tf
git commit -m "feat(tf): add terraform root module skeleton with S3 backend"
```

---

## Task 3: S3 bucket `hooks-fyi-request-files`

**Files:**
- Create: `terraform/s3.tf`

- [ ] **Step 1: Write `terraform/s3.tf`**

```hcl
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
```

- [ ] **Step 2: Verify (if terraform installed)**

```bash
cd <repo-root>/terraform
terraform fmt -check
terraform validate
```
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd <repo-root>
git add terraform/s3.tf
git commit -m "feat(tf): add hooks-fyi-request-files S3 bucket"
```

---

## Task 4: IAM user `hooks-fyi` with bucket read-write policy

**Files:**
- Create: `terraform/iam.tf`

- [ ] **Step 1: Write `terraform/iam.tf`**

```hcl
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
```

> The access key + secret are stored in Terraform state (encrypted in S3). To read them post-apply: `terraform output -raw hooks_fyi_secret_access_key`. We accept this trade-off: state is in an encrypted, access-controlled S3 bucket; the alternative (creating keys manually in console) defeats IaC.

- [ ] **Step 2: Verify (if terraform installed)**

```bash
cd <repo-root>/terraform
terraform fmt -check
terraform validate
```
Expected: `Success!`

- [ ] **Step 3: Commit**

```bash
cd <repo-root>
git add terraform/iam.tf
git commit -m "feat(tf): add hooks-fyi IAM user with bucket read-write policy"
```

---

## Task 5: Backend bootstrap script

**Files:**
- Create: `scripts/bootstrap-backend.sh`

- [ ] **Step 1: Write `scripts/bootstrap-backend.sh`**

```bash
#!/usr/bin/env bash
# Creates the S3 bucket and DynamoDB lock table used as the Terraform remote
# state backend for this repo. Run once per AWS account, before the first
# `terraform apply`.
#
# Usage:
#   AWS_PROFILE=hooks-fyi ./scripts/bootstrap-backend.sh
#
# Idempotent: re-running is safe; existing resources are left alone.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET="${STATE_BUCKET:-hooks-fyi-tfstate}"
LOCK_TABLE="${LOCK_TABLE:-hooks-fyi-tflock}"

echo "Region:       $REGION"
echo "State bucket: $STATE_BUCKET"
echo "Lock table:   $LOCK_TABLE"
echo

# --- S3 bucket ---------------------------------------------------------------
if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  echo "✓ Bucket $STATE_BUCKET already exists."
else
  echo "→ Creating bucket $STATE_BUCKET ..."
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
fi

echo "→ Enabling versioning ..."
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

echo "→ Enabling default encryption (AES256) ..."
aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]
  }'

echo "→ Blocking all public access ..."
aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration '{
    "BlockPublicAcls":true,"IgnorePublicAcls":true,
    "BlockPublicPolicy":true,"RestrictPublicBuckets":true
  }'

# --- DynamoDB lock table -----------------------------------------------------
if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "✓ Lock table $LOCK_TABLE already exists."
else
  echo "→ Creating lock table $LOCK_TABLE ..."
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --region "$REGION" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
  aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$REGION"
fi

echo
echo "✓ Backend ready. You can now run terraform from CI or locally."
```

- [ ] **Step 2: Make it executable and sanity-check shell syntax**

```bash
cd <repo-root>
chmod +x scripts/bootstrap-backend.sh
bash -n scripts/bootstrap-backend.sh
```
Expected: no output (syntax OK).

- [ ] **Step 3: Commit**

```bash
git add scripts/bootstrap-backend.sh
git commit -m "feat(scripts): add S3 + DynamoDB backend bootstrap script"
```

---

## Task 6: Architecture documentation

**Files:**
- Create: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Write `docs/ARCHITECTURE.md`**

```markdown
# Architecture

## Purpose

`aws-resources` is the single source of truth for AWS infrastructure managed under the `jorgejr568` account, applied through CI/CD. Every change to AWS state goes through a PR, a `terraform plan`, a review, and a `terraform apply` triggered by merging to `main`.

## Repository layout

```
.
├── .github/workflows/   # CI/CD entrypoints
├── terraform/           # root module — all current resources
├── scripts/             # one-off operational scripts
├── docs/                # design + decision records
├── .tool-versions       # tfenv / asdf hint (terraform version)
└── README.md            # quick-start for humans
```

### `terraform/` is a single root module

For now there is exactly one Terraform configuration. Splitting into modules or per-environment stacks is intentionally deferred (YAGNI) until we have:
- A second environment (staging, prod), or
- A reusable resource pattern repeated across files (e.g. multiple buckets each with their own writer user).

When that day comes, the `terraform/` directory becomes `terraform/envs/<env>/` and shared logic moves to `terraform/modules/`.

### Files inside `terraform/`

| File | Responsibility |
|------|----------------|
| `versions.tf`  | Terraform + provider version constraints |
| `providers.tf` | `aws` provider config + default tags |
| `backend.tf`   | S3 + DynamoDB remote state |
| `variables.tf` | Input variables (region, etc.) |
| `outputs.tf`   | Cross-cutting outputs (most outputs live next to their resource) |
| `s3.tf`        | All S3 buckets and their hardening (encryption, public-access-block, versioning, ownership) |
| `iam.tf`       | All IAM users, policies, attachments, access keys |

Resources are grouped by AWS service, not by feature. When a feature spans services (e.g. "hooks-fyi" = bucket + user + policy), the pieces live in their service-appropriate file and are wired through Terraform references.

## State management

State is stored remotely in:
- **Bucket:** `hooks-fyi-tfstate` (versioned, AES256-encrypted, public access blocked)
- **Lock table:** `hooks-fyi-tflock` (DynamoDB, on-demand billing)
- **Region:** `us-east-1`
- **Key:** `aws-resources/terraform.tfstate`

Both are created once via `scripts/bootstrap-backend.sh`. The script is idempotent so re-running it is safe.

> ⚠ State contains sensitive values (notably IAM access key secrets). Read access to `hooks-fyi-tfstate` should be restricted to the same humans/automation that can apply this repo.

## Authentication

GitHub Actions authenticates to AWS using long-lived access keys for an IAM user with administrative-equivalent permissions on the resources we manage, stored as repo secrets:

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID`     | CI access key id |
| `AWS_SECRET_ACCESS_KEY` | CI secret |

The CI user is **not** the same as `hooks-fyi`. `hooks-fyi` is an application service account managed by Terraform and has only S3 read-write permissions to one bucket. The CI user is an account-level admin (or scoped to "manage S3+IAM in this account") and is created out-of-band.

> **Future work:** Replace the CI access keys with GitHub OIDC + an IAM role (`role-to-assume`). This eliminates long-lived secrets. Tracked as an issue once we ship v1.

## CI/CD flows

### Plan (on PR)
Trigger: `pull_request` targeting `main`, when `terraform/**` or workflow files change.
Steps:
1. Checkout
2. Configure AWS credentials
3. `terraform fmt -check -recursive`
4. `terraform init`
5. `terraform validate`
6. `terraform plan -no-color -out=tfplan`
7. Comment plan output on the PR

### Apply (on merge / manual)
Triggers:
- `push` to `main` when `terraform/**` or workflow files change.
- `workflow_dispatch` (manual run from the Actions tab).
Steps:
1. Checkout
2. Configure AWS credentials
3. `terraform init`
4. `terraform plan -no-color -out=tfplan`
5. `terraform apply -auto-approve tfplan`

Apply runs serially via a GitHub Actions `concurrency` group keyed to the workflow + ref so two merges can't race.

## Bootstrap order (one-time, per AWS account)

1. Create the CI IAM user (admin-ish) **outside** this repo and capture its keys.
2. Run `./scripts/bootstrap-backend.sh` from a machine logged in to that account.
3. Add `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` as GitHub repo secrets.
4. Push to `main` (or rerun the apply workflow). CI takes over from here.

## Adding a new resource

1. Branch off `main`.
2. Add or extend a file in `terraform/` matching the AWS service (`s3.tf`, `iam.tf`, …; create new `<service>.tf` files as needed).
3. Open a PR. The plan workflow comments the diff.
4. Get review, merge. The apply workflow rolls it out.

## Reading sensitive outputs

```bash
cd terraform
terraform output -raw hooks_fyi_secret_access_key
```
Requires read access to the state bucket. Don't commit, don't paste in chat.
```

- [ ] **Step 2: Commit**

```bash
cd <repo-root>
git add docs/ARCHITECTURE.md
git commit -m "docs: add architecture overview"
```

---

## Task 7: GitHub Actions plan workflow

**Files:**
- Create: `.github/workflows/terraform-plan.yml`

- [ ] **Step 1: Write `.github/workflows/terraform-plan.yml`**

```yaml
name: terraform-plan

on:
  pull_request:
    branches: [main]
    paths:
      - "terraform/**"
      - ".github/workflows/terraform-plan.yml"
      - ".github/workflows/terraform-apply.yml"

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: terraform-plan-${{ github.ref }}
  cancel-in-progress: true

jobs:
  plan:
    name: plan
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.8
          terraform_wrapper: false

      - name: terraform fmt
        id: fmt
        run: terraform fmt -check -recursive
        continue-on-error: true

      - name: terraform init
        id: init
        run: terraform init -input=false

      - name: terraform validate
        id: validate
        run: terraform validate -no-color

      - name: terraform plan
        id: plan
        run: |
          set +e
          terraform plan -no-color -input=false -out=tfplan > plan.txt 2>&1
          echo "exitcode=$?" >> "$GITHUB_OUTPUT"
          cat plan.txt

      - name: Comment plan on PR
        if: always()
        uses: actions/github-script@v7
        env:
          PLAN_EXIT: ${{ steps.plan.outputs.exitcode }}
          FMT_OUTCOME: ${{ steps.fmt.outcome }}
          INIT_OUTCOME: ${{ steps.init.outcome }}
          VALIDATE_OUTCOME: ${{ steps.validate.outcome }}
        with:
          script: |
            const fs = require('fs');
            const path = 'terraform/plan.txt';
            let plan = '(no plan output)';
            try { plan = fs.readFileSync(path, 'utf8'); } catch (_) {}
            const max = 60000;
            if (plan.length > max) plan = plan.slice(0, max) + '\n\n…(truncated)';

            const body = [
              '### Terraform plan',
              '',
              `- **fmt:** \`${process.env.FMT_OUTCOME}\``,
              `- **init:** \`${process.env.INIT_OUTCOME}\``,
              `- **validate:** \`${process.env.VALIDATE_OUTCOME}\``,
              `- **plan exit code:** \`${process.env.PLAN_EXIT}\``,
              '',
              '<details><summary>Plan output</summary>',
              '',
              '```hcl',
              plan,
              '```',
              '',
              '</details>',
            ].join('\n');

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body,
            });

      - name: Fail if plan errored
        if: steps.plan.outputs.exitcode != '0' && steps.plan.outputs.exitcode != '2'
        run: |
          echo "terraform plan failed (exit ${{ steps.plan.outputs.exitcode }})"
          exit 1

      - name: Fail if fmt drift
        if: steps.fmt.outcome == 'failure'
        run: |
          echo "terraform fmt drift detected. Run 'terraform fmt -recursive' locally."
          exit 1
```

> Plan exit code semantics: `0` = no changes, `2` = changes pending (success), `1` = error.

- [ ] **Step 2: Sanity-check YAML syntax**

```bash
cd <repo-root>
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/terraform-plan.yml'))" && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/terraform-plan.yml
git commit -m "ci: add terraform plan workflow with PR comment"
```

---

## Task 8: GitHub Actions apply workflow

**Files:**
- Create: `.github/workflows/terraform-apply.yml`

- [ ] **Step 1: Write `.github/workflows/terraform-apply.yml`**

```yaml
name: terraform-apply

on:
  push:
    branches: [main]
    paths:
      - "terraform/**"
      - ".github/workflows/terraform-apply.yml"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: terraform-apply
  cancel-in-progress: false

jobs:
  apply:
    name: apply
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.8
          terraform_wrapper: false

      - name: terraform init
        run: terraform init -input=false

      - name: terraform validate
        run: terraform validate -no-color

      - name: terraform plan
        run: terraform plan -no-color -input=false -out=tfplan

      - name: terraform apply
        run: terraform apply -auto-approve -input=false tfplan
```

- [ ] **Step 2: Sanity-check YAML**

```bash
cd <repo-root>
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/terraform-apply.yml'))" && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/terraform-apply.yml
git commit -m "ci: add terraform apply workflow"
```

---

## Task 9: Add this plan file to git

The plan file already exists at `docs/superpowers/plans/2026-04-29-aws-resources-bootstrap.md` but is untracked. Commit it so it ships with the repo for future readers.

- [ ] **Step 1: Commit the plan**

```bash
cd <repo-root>
git add docs/superpowers/plans/2026-04-29-aws-resources-bootstrap.md
git commit -m "docs: add bootstrap implementation plan"
```

- [ ] **Step 2: Verify final tree**

```bash
git log --oneline
git ls-files
```
Expected: 8 commits, clean tree, files match the layout in the plan header.

---

## Task 10: Create private GitHub repo and push

- [ ] **Step 1: Confirm `gh` is authenticated as the right user**

```bash
gh auth status
```
Expected: logged in as `jorgejr568`.

- [ ] **Step 2: Create the private repo (no auto-push, no auto-clone)**

```bash
cd <repo-root>
gh repo create jorgejr568/aws-resources \
  --private \
  --description "Terraform-managed AWS resources, applied via GitHub Actions." \
  --source=. \
  --remote=origin
```
Expected: repo created at `https://github.com/jorgejr568/aws-resources`, `origin` remote added locally.

- [ ] **Step 3: Push**

```bash
git push -u origin main
```
Expected: push succeeds; default branch `main` set.

- [ ] **Step 4: Confirm the apply workflow has been triggered**

```bash
sleep 5
gh run list --repo jorgejr568/aws-resources --limit 5
```
Expected: a run for `terraform-apply` is queued or running. It will fail (no secrets yet, no state backend) — that's expected and documented in the handoff below.

- [ ] **Step 5: Print handoff instructions for the user**

After the push, surface this to the user verbatim:

```
Repo: https://github.com/jorgejr568/aws-resources

Next steps (you do these):
1. Switch your shell to the correct AWS account credentials.
2. Run: ./scripts/bootstrap-backend.sh
   This creates the hooks-fyi-tfstate bucket and hooks-fyi-tflock DynamoDB table.
3. Add repo secrets at https://github.com/jorgejr568/aws-resources/settings/secrets/actions
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   (Use a CI IAM user that can manage S3 + IAM. NOT the hooks-fyi user.)
4. Re-run the terraform-apply workflow:
   gh run rerun --repo jorgejr568/aws-resources <run-id>
   or click "Re-run all jobs" in the Actions UI.
5. Once apply succeeds, retrieve the hooks-fyi credentials:
   cd terraform
   terraform output -raw hooks_fyi_access_key_id
   terraform output -raw hooks_fyi_secret_access_key
```

---

## Self-review notes (for the executor)

Before declaring done, re-read these from the spec and confirm they exist in the plan:

- ✅ Terraform repo at this path (Task 1, 2)
- ✅ S3 bucket `hooks-fyi-request-files` (Task 3)
- ✅ IAM user `hooks-fyi` with policies to write to that bucket (Task 4)
- ✅ CI/CD pipeline with GitHub Actions (Tasks 7, 8)
- ✅ Good documentation of repo structure (Task 6 — `docs/ARCHITECTURE.md`)
- ✅ Nothing is run locally that touches AWS (verification via `terraform fmt`/`validate` only, all apply happens in CI)
- ✅ Private repo created via `gh` CLI (Task 10)
- ✅ User adds secrets and reruns (Task 10 handoff)
