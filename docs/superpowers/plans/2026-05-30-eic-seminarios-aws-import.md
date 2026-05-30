# eic-seminarios AWS Resources Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the existing `eic-seminarios` AWS footprint (S3, IAM, SES, CloudFront, ACM) under Terraform in this repo, via native `import {}` blocks, so it works with `plan`/`apply` without disrupting live data, the verified SES domain, or live credentials.

**Architecture:** All resources live in the existing `terraform/projects/eic-seminarios/` module (which today only manages Cloudflare DNS). A new `aws.eic_seminarios` provider alias is wired into the module. Resources are authored to match live state exactly and adopted with root-level `import {}` blocks (collected in `terraform/imports-eic-seminarios.tf`, since Terraform only allows import blocks in the root module). SES gets a brand-new project-named configuration set rather than adopting the console default. The guide-uploader access key is regenerated (secret was lost); all other keys are imported.

**Tech Stack:** Terraform 1.10.5, hashicorp/aws ~> 6.0 (incl. SESv2), cloudflare/cloudflare ~> 5.0. State in S3 backend `jorgejr568-aws-resources-tfstate`. Account `730335335283`, region `us-east-1`.

**Design spec:** [docs/superpowers/specs/2026-05-30-eic-seminarios-aws-import-design.md](../specs/2026-05-30-eic-seminarios-aws-import-design.md)

---

## Definition of done (the target `terraform plan`)

After all tasks, `terraform plan` (run with the env from "Prerequisites") must show **only** this action set and nothing else:

- **All imported resources: 0 changes** (config matches live state).
- **Creates (4):** SES config set `eic-seminarios`, its event destination `eic-seminarios-ses-dashboard`, the fresh guide-uploader access key, and `aws_acm_certificate_validation.guide` (a synthetic resource with no cloud object — it just records that the already-issued cert is validated).
- **Updates (2):** the two SES identities re-pointing their default configuration set from `my-first-configuration-set` to `eic-seminarios`.
- **No replaces. No destroys. No drift on any other project.**

CloudFront and S3 imports are config-sensitive; expect to iterate the HCL until the plan is clean. That iteration *is* the work — don't accept a plan that wants to change an imported resource.

---

## Prerequisites (every task that runs `terraform plan`)

Local `plan` needs the same env CI injects. AWS creds are already the active default profile (`terraform-ci`, account `730335335283`). Fetch the rest at runtime so no secrets land in the repo. Run from the repo root:

```bash
cd terraform
export CLOUDFLARE_API_TOKEN="$(tr -d '[:space:]' < ~/.personal-cloudflare-token)"
ZID="$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  'https://api.cloudflare.com/client/v4/zones?name=eic-seminarios.com' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"][0]["id"])')"
export TF_VAR_cloudflare_account_id="$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  'https://api.cloudflare.com/client/v4/zones?name=eic-seminarios.com' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"][0]["account"]["id"])')"
export TF_VAR_server_ipv4="$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZID/dns_records?type=A&name=beta.eic-seminarios.com" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"][0]["content"])')"
export TF_VAR_server_ipv6="$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZID/dns_records?type=AAAA&name=beta.eic-seminarios.com" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"][0]["content"])')"
# sanity check (no secrets printed except the IPs, which are non-sensitive infra values):
echo "account_id set: ${TF_VAR_cloudflare_account_id:+yes}  ipv4 set: ${TF_VAR_server_ipv4:+yes}  ipv6 set: ${TF_VAR_server_ipv6:+yes}"
```

> **Never** apply locally. Apply happens only in CI on merge to `main`. Locally we only `plan` to drive imports to a clean state.

---

## File structure

| File | Responsibility |
|---|---|
| `terraform/providers.tf` (modify) | Add `aws.eic_seminarios` provider alias |
| `terraform/main.tf` (modify) | Pass `aws = aws.eic_seminarios` into the `eic_seminarios` module |
| `terraform/projects/eic-seminarios/versions.tf` (modify) | Add `aws ~> 6.0` to required_providers |
| `terraform/projects/eic-seminarios/s3.tf` (create) | Both S3 buckets + sub-resources |
| `terraform/projects/eic-seminarios/cloudfront.tf` (create) | ACM cert, Cloudflare validation record, ACM validation, CloudFront distribution |
| `terraform/projects/eic-seminarios/ses.tf` (create) | New config set + event destination, two SESv2 identities, MAIL FROM |
| `terraform/projects/eic-seminarios/iam.tf` (create) | Two IAM users, managed + inline policies, access keys |
| `terraform/imports-eic-seminarios.tf` (create, root) | All `import {}` blocks; removed in a post-apply follow-up |
| `.trivyignore` (modify) | Justified suppressions for the intentionally-public guide bucket + CloudFront |

Task order respects dependencies: wiring → S3 → CloudFront/ACM → SES → IAM (IAM references both buckets and the distribution ARN).

---

## Task 1: Provider wiring

**Files:**
- Modify: `terraform/providers.tf`
- Modify: `terraform/main.tf`
- Modify: `terraform/projects/eic-seminarios/versions.tf`

- [ ] **Step 1: Add the AWS provider alias**

In `terraform/providers.tf`, add after the `organizze_mcp` aliased provider (before the `cloudflare` provider block):

```hcl
provider "aws" {
  alias  = "eic_seminarios"
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
      Project   = "eic-seminarios"
    }
  }
}
```

- [ ] **Step 2: Pass the AWS provider into the module**

In `terraform/main.tf`, replace the `eic_seminarios` module's `providers` map:

```hcl
module "eic_seminarios" {
  source = "./projects/eic-seminarios"

  server_ipv4 = var.server_ipv4
  server_ipv6 = var.server_ipv6

  providers = {
    aws        = aws.eic_seminarios
    cloudflare = cloudflare
  }
}
```

- [ ] **Step 3: Declare the AWS provider in the module**

Replace `terraform/projects/eic-seminarios/versions.tf` with:

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 4: Init and validate**

Run (after the Prerequisites env block):
```bash
terraform init -input=false
terraform validate -no-color
```
Expected: init succeeds (no new providers to download — aws/cloudflare already in lock), validate prints `Success! The configuration is valid.`

- [ ] **Step 5: Plan to confirm no drift introduced**

Run: `terraform plan -no-color -input=false`
Expected: `No changes. Your infrastructure matches the configuration.` (We only added an unused provider alias; nothing should change yet.)

- [ ] **Step 6: fmt and commit**

```bash
terraform fmt -recursive
git add terraform/providers.tf terraform/main.tf terraform/projects/eic-seminarios/versions.tf
git commit -m "feat(eic-seminarios): wire aws provider into module"
```

---

## Task 2: S3 buckets

**Files:**
- Create: `terraform/projects/eic-seminarios/s3.tf`
- Create/append: `terraform/imports-eic-seminarios.tf`

- [ ] **Step 1: Write `s3.tf`**

```hcl
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
    sid       = "PublicReadGetObject"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.guide.arn}/*"]

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
```

- [ ] **Step 2: Add S3 import blocks**

Create `terraform/imports-eic-seminarios.tf` with:

```hcl
# Import blocks for adopting the existing eic-seminarios AWS resources.
# Import blocks must live in the root module and reference resources via the
# module path. Remove this file in a follow-up PR after the import apply succeeds.

import {
  to = module.eic_seminarios.aws_s3_bucket.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_versioning.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_server_side_encryption_configuration.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_public_access_block.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_ownership_controls.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_server_side_encryption_configuration.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_ownership_controls.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_public_access_block.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_website_configuration.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_policy.guide
  id = "guide.eic-seminarios.com"
}
```

- [ ] **Step 3: Plan and verify clean S3 import**

Run: `terraform plan -no-color -input=false`
Expected: the 11 S3 resources show `will be imported` with **no attribute changes** ("0 to add, 0 to change, 0 to destroy" once imports are subtracted — the plan summary line reads `Plan: 0 to add, 0 to change, 0 to destroy. N to import.`).
If any imported S3 resource shows a change, fix the HCL to match live state and re-plan. (Watch `bucket_key_enabled` true vs false between the two buckets.)

- [ ] **Step 4: fmt and commit**

```bash
terraform fmt -recursive
git add terraform/projects/eic-seminarios/s3.tf terraform/imports-eic-seminarios.tf
git commit -m "feat(eic-seminarios): import S3 buckets"
```

---

## Task 3: CloudFront, ACM certificate, and Cloudflare validation record

**Files:**
- Create: `terraform/projects/eic-seminarios/cloudfront.tf`
- Append: `terraform/imports-eic-seminarios.tf`

- [ ] **Step 1: Write `cloudfront.tf`**

The Cloudflare zone data source `data.cloudflare_zone.eic_seminarios` already exists in `cloudflare.tf` — reuse it for the validation record's `zone_id`.

```hcl
resource "aws_acm_certificate" "guide" {
  domain_name       = "guide.eic-seminarios.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM DNS-validation CNAME (already present in Cloudflare; imported).
resource "cloudflare_dns_record" "acm_guide_validation" {
  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = "_96edaf591a8248fcdf34a050fe98e34c.guide.eic-seminarios.com"
  type    = "CNAME"
  content = "_22162c9f330487ff0020c1cd040af1da.jkddzztszm.acm-validations.aws"
  ttl     = 1
  proxied = false
}

resource "aws_acm_certificate_validation" "guide" {
  certificate_arn         = aws_acm_certificate.guide.arn
  validation_record_fqdns = [cloudflare_dns_record.acm_guide_validation.name]
}

resource "aws_cloudfront_distribution" "guide" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2"
  price_class         = "PriceClass_All"
  aliases             = ["guide.eic-seminarios.com"]
  default_root_object = "index.html"
  comment             = "CEFET-RJ Seminarios Guide Documentation"

  origin {
    origin_id   = "S3-guide"
    domain_name = "guide.eic-seminarios.com.s3-website-us-east-1.amazonaws.com"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  default_cache_behavior {
    target_origin_id       = "S3-guide"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.guide.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

output "guide_distribution_id" {
  description = "CloudFront distribution ID serving guide.eic-seminarios.com."
  value       = aws_cloudfront_distribution.guide.id
}
```

- [ ] **Step 2: Append CloudFront/ACM import blocks**

Append to `terraform/imports-eic-seminarios.tf`:

```hcl
import {
  to = module.eic_seminarios.aws_acm_certificate.guide
  id = "arn:aws:acm:us-east-1:730335335283:certificate/b36e7001-bbd0-443f-8acb-c84eadc0973b"
}
import {
  to = module.eic_seminarios.cloudflare_dns_record.acm_guide_validation
  id = "a0cad208e1aacc23ef78414b46d22cb9/deaf1e1a1a78b7bde7bde2a3478067f1"
}
import {
  to = module.eic_seminarios.aws_cloudfront_distribution.guide
  id = "E34WTTE9HV683E"
}
```

> No import block for `aws_acm_certificate_validation.guide` — it is a synthetic resource with no cloud object and is created (instantly, since the cert is already ISSUED).

- [ ] **Step 3: Plan and iterate until CloudFront/ACM import is clean**

Run: `terraform plan -no-color -input=false`
Expected: `aws_acm_certificate.guide`, `cloudflare_dns_record.acm_guide_validation`, and `aws_cloudfront_distribution.guide` import with **0 changes**; `aws_acm_certificate_validation.guide` shows **1 to add**.
CloudFront distributions are picky — if the plan wants to change the imported distribution, align the HCL to the live config (common culprits: `forwarded_values` vs a cache policy, `compress`, `min_ttl`, missing `default_root_object`). Re-plan until only the validation resource is a create.

- [ ] **Step 4: fmt and commit**

```bash
terraform fmt -recursive
git add terraform/projects/eic-seminarios/cloudfront.tf terraform/imports-eic-seminarios.tf
git commit -m "feat(eic-seminarios): import CloudFront distribution + ACM cert"
```

---

## Task 4: SES (new config set + identities)

**Files:**
- Create: `terraform/projects/eic-seminarios/ses.tf`
- Append: `terraform/imports-eic-seminarios.tf`

- [ ] **Step 1: Write `ses.tf`**

```hcl
# New, project-owned configuration set (replaces the console default
# "my-first-configuration-set" as the identities' default). Same settings.
resource "aws_sesv2_configuration_set" "main" {
  configuration_set_name = "eic-seminarios"

  reputation_options {
    reputation_metrics_enabled = true
  }

  sending_options {
    sending_enabled = true
  }
}

resource "aws_sesv2_configuration_set_event_destination" "dashboard" {
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
  event_destination_name = "eic-seminarios-ses-dashboard"

  event_destination {
    enabled = true
    matching_event_types = [
      "SEND",
      "REJECT",
      "BOUNCE",
      "COMPLAINT",
      "DELIVERY",
      "OPEN",
      "CLICK",
      "RENDERING_FAILURE",
      "DELIVERY_DELAY",
    ]

    cloud_watch_destination {
      dimension_configuration {
        default_dimension_value = "eic-seminarios-ses"
        dimension_name          = "origin"
        dimension_value_source  = "MESSAGE_TAG"
      }
    }
  }
}

resource "aws_sesv2_email_identity" "eic_seminarios" {
  email_identity         = "eic-seminarios.com"
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
}

resource "aws_sesv2_email_identity_mail_from_attributes" "eic_seminarios" {
  email_identity         = aws_sesv2_email_identity.eic_seminarios.email_identity
  mail_from_domain       = "ses.eic-seminarios.com"
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

resource "aws_sesv2_email_identity" "no_reply" {
  email_identity         = "no-reply@eic-seminarios.com"
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
}

output "eic_seminarios_dkim_tokens" {
  description = "SES Easy DKIM tokens for eic-seminarios.com. For each token <t>, a CNAME at <t>._domainkey.eic-seminarios.com points to <t>.dkim.amazonses.com (already in Cloudflare, manually managed)."
  value       = aws_sesv2_email_identity.eic_seminarios.dkim_signing_attributes[0].tokens
}
```

- [ ] **Step 2: Append SES import blocks**

Append to `terraform/imports-eic-seminarios.tf`:

```hcl
import {
  to = module.eic_seminarios.aws_sesv2_email_identity.eic_seminarios
  id = "eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_sesv2_email_identity_mail_from_attributes.eic_seminarios
  id = "eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_sesv2_email_identity.no_reply
  id = "no-reply@eic-seminarios.com"
}
```

> No import for the config set / event destination — they are newly created.

- [ ] **Step 3: Plan and verify SES**

Run: `terraform plan -no-color -input=false`
Expected:
- `aws_sesv2_configuration_set.main` and `aws_sesv2_configuration_set_event_destination.dashboard`: **2 to add**.
- `aws_sesv2_email_identity.eic_seminarios` and `.no_reply`: imported, each showing **1 change** — `configuration_set_name` going from `"my-first-configuration-set"` → `"eic-seminarios"`. No other changes.
- `aws_sesv2_email_identity_mail_from_attributes.eic_seminarios`: imported, **0 changes**.

If the DKIM output errors on `dkim_signing_attributes[0]`, adjust to the correct attribute path the provider exposes (e.g. wrap with `tolist(...)[0].tokens`) and re-plan.

- [ ] **Step 4: fmt and commit**

```bash
terraform fmt -recursive
git add terraform/projects/eic-seminarios/ses.tf terraform/imports-eic-seminarios.tf
git commit -m "feat(eic-seminarios): import SES identities, add owned config set"
```

---

## Task 5: IAM users, policies, and access keys

**Files:**
- Create: `terraform/projects/eic-seminarios/iam.tf`
- Append: `terraform/imports-eic-seminarios.tf`

- [ ] **Step 1: Write `iam.tf`**

The managed policy `eic-seminarios-ses` has **no Sids** on its statements live — do **not** add `sid` arguments, or the imported policy will show a diff. Resource ARNs use the bucket/distribution references to stay DRY (they render to the exact live ARNs).

```hcl
# Main application service user: SES send (restricted senders), S3 rw on the
# app bucket, and CloudWatch Logs for the seminarios-eic log group.
resource "aws_iam_user" "eic_seminarios" {
  name = "eic-seminarios"
  path = "/"
}

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
      aws_s3_bucket.eic_seminarios.arn,
      "${aws_s3_bucket.eic_seminarios.arn}/*",
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

# Two existing access keys, imported (secrets retained by the user; not output).
resource "aws_iam_access_key" "eic_seminarios" {
  for_each = toset(["2026-01", "2024-10"])
  user     = aws_iam_user.eic_seminarios.name
}

# Guide deploy user: write to the guide bucket + invalidate the CloudFront dist.
resource "aws_iam_user" "guide_uploader" {
  name = "eic-seminarios-guide-uploader"
  path = "/"
}

data "aws_iam_policy_document" "guide_sync" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.guide.arn,
      "${aws_s3_bucket.guide.arn}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.guide.arn]
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
```

- [ ] **Step 2: Append IAM import blocks**

Append to `terraform/imports-eic-seminarios.tf`:

```hcl
import {
  to = module.eic_seminarios.aws_iam_user.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_iam_policy.eic_seminarios_ses
  id = "arn:aws:iam::730335335283:policy/eic-seminarios-ses"
}
import {
  to = module.eic_seminarios.aws_iam_user_policy_attachment.eic_seminarios_ses
  id = "eic-seminarios/arn:aws:iam::730335335283:policy/eic-seminarios-ses"
}
import {
  to = module.eic_seminarios.aws_iam_access_key.eic_seminarios["2026-01"]
  id = "AKIA2UC3A2NZQRMLBG3Q"
}
import {
  to = module.eic_seminarios.aws_iam_access_key.eic_seminarios["2024-10"]
  id = "AKIA2UC3A2NZTNO5HVHT"
}
import {
  to = module.eic_seminarios.aws_iam_user.guide_uploader
  id = "eic-seminarios-guide-uploader"
}
import {
  to = module.eic_seminarios.aws_iam_user_policy.guide_sync
  id = "eic-seminarios-guide-uploader:S3GuideSync"
}
```

> No import for `aws_iam_access_key.guide_uploader` — it is newly created.

- [ ] **Step 3: Plan and verify IAM**

Run: `terraform plan -no-color -input=false`
Expected: users, managed policy, attachment, inline policy, and both main access keys import with **0 changes**; `aws_iam_access_key.guide_uploader` shows **1 to add**.
If the managed policy `eic_seminarios_ses` shows a change, the rendered JSON differs from live — check statement actions/resources/condition and that no `sid` was added. Re-plan until clean.

- [ ] **Step 4: fmt and commit**

```bash
terraform fmt -recursive
git add terraform/projects/eic-seminarios/iam.tf terraform/imports-eic-seminarios.tf
git commit -m "feat(eic-seminarios): import IAM users and policies; rotate guide key"
```

---

## Task 6: Satisfy lint/security gates and confirm full plan

**Files:**
- Modify: `.trivyignore`

- [ ] **Step 1: Run the full local plan and confirm it matches "Definition of done"**

Run: `terraform plan -no-color -input=false`
Expected summary line: `Plan: 4 to add, 2 to change, 0 to destroy. 24 to import.`
(4 add = config set, event destination, guide key, acm validation. 2 change = the two SES identity config-set updates. 24 import = 11 S3 + 3 CloudFront/ACM + 3 SES + 7 IAM.)
If the counts differ or any imported resource shows a change, return to the relevant task and fix the HCL.

- [ ] **Step 2: Run Trivy and capture intentional HIGH/CRITICAL findings**

Run: `trivy config terraform/ --severity HIGH,CRITICAL --ignorefile .trivyignore`
The intentionally-public guide bucket and the CloudFront distribution will produce findings (e.g. public S3 access, CloudFront access logging disabled, no WAF, insecure `http-only`/`TLSv1` origin protocol). For each finding that is **intentional** for this design, add its `AVD-...` ID to `.trivyignore` with a one-line justification. Do not blanket-ignore; add only the IDs Trivy actually reports.

Example additions (replace with the exact IDs Trivy prints):
```
# AVD-AWS-XXXX: guide.eic-seminarios.com is a deliberately public static-site
# bucket fronted by CloudFront; public-read on objects is required.
AVD-AWS-XXXX

# AVD-AWS-YYYY: CloudFront access logging not enabled — personal docs site,
# no audit requirement; avoids the log bucket + cost.
AVD-AWS-YYYY
```

- [ ] **Step 3: Re-run Trivy to confirm clean**

Run: `trivy config terraform/ --severity HIGH,CRITICAL --ignorefile .trivyignore`
Expected: no HIGH/CRITICAL findings reported (exit 0).

- [ ] **Step 4: Run tflint**

Run (from `terraform/`): `tflint --init && tflint --recursive --format=compact`
Expected: no errors. Fix any reported issues (e.g. unused declarations) and re-run.

- [ ] **Step 5: fmt check and commit**

```bash
cd terraform && terraform fmt -check -recursive && cd ..
git add .trivyignore
git commit -m "chore(eic-seminarios): suppress intentional trivy findings for public guide site"
```

---

## Task 7: Open PR and verify CI plan

- [ ] **Step 1: Push the branch and open a PR**

```bash
git push -u origin "$(git rev-parse --abbrev-ref HEAD)"
gh pr create --fill --base main
```

- [ ] **Step 2: Confirm the CI `terraform-plan` matches the local plan**

Watch the PR's `pr-checks` run. The `terraform-plan` comment must show the same action set as the Definition of done (plan exit code `2` = changes pending, which is expected here because of the 4 creates + 2 updates + imports). `tflint` and `trivy-config` must pass.

- [ ] **Step 3: Merge to trigger apply**

On merge to `main`, `terraform-apply` runs the imports and creates the new resources/key. After it succeeds, proceed to the follow-ups below.

---

## Post-apply follow-ups (not part of this PR)

1. **Retrieve the new guide key** from state and update the guide deploy:
   ```bash
   cd terraform
   terraform output -raw guide_uploader_access_key_id
   terraform output -raw guide_uploader_secret_access_key
   ```
   Then **delete the old key**: `aws iam delete-access-key --user-name eic-seminarios-guide-uploader --access-key-id AKIA2UC3A2NZ3WOIMLGE`
2. **Remove `terraform/imports-eic-seminarios.tf`** in a follow-up PR (import blocks are no-ops once state is populated; HashiCorp recommends removing them).
3. **Delete the old default SES config set** `my-first-configuration-set` once nothing sends through it, and update the app if it passes that name explicitly in send calls.

---

## Self-review notes

- **Spec coverage:** provider wiring (Task 1), both S3 buckets (Task 2), CloudFront+ACM+CF-validation (Task 3), SES new config set + identities + MAIL FROM (Task 4), both IAM users + policies + keys (Task 5), lint/security gates + full-plan check (Task 6), PR/apply (Task 7), and all spec follow-ups captured. ✓
- **Import-block location:** root module (`imports-eic-seminarios.tf`) referencing `module.eic_seminarios.*`, because Terraform disallows import blocks in child modules. ✓
- **No-Sid managed policy:** Task 5 explicitly omits `sid` to match the live policy and avoid a diff. ✓
- **Created vs imported:** guide-uploader key, SES config set + event destination, and `aws_acm_certificate_validation` are creates (no import blocks); everything else is imported. ✓
- **Type/name consistency:** resource addresses in import blocks match the resource names in the module files (`eic_seminarios`, `guide`, `main`, `dashboard`, `no_reply`, `guide_uploader`, `acm_guide_validation`). ✓
