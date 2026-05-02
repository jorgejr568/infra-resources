# Polish `infra-resources` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten the repo on five axes — DRY refactor of repeated Cloudflare DNS patterns, removal of dead code, CI hardening, dependency version bumps, and documentation cleanup — with every step producing a no-op `terraform plan`.

**Architecture:** Five sequenced PRs against `main`. Each PR is independently mergeable and CI-verifiable. State-preserving Terraform refactors use `moved {}` blocks. Local validation uses `terraform init -backend=false && terraform fmt -check && terraform validate` to avoid needing AWS credentials.

**Tech Stack:** Terraform 1.10.5, AWS provider `~> 5.70`, Cloudflare provider `~> 4.40`, GitHub Actions, `terraform-linters/tflint` v4, `aquasecurity/trivy-action@0.28.0`, `antonbabenko/pre-commit-terraform`.

**Spec:** `docs/superpowers/specs/2026-05-02-polish-repo-design.md`

---

## File map

**Created:**
- `terraform/modules/cloudflare-proxied-subdomains/main.tf` — A+AAAA pair per subdomain
- `terraform/modules/cloudflare-proxied-subdomains/variables.tf` — `zone_id`, `subdomains`, `ipv4`, `ipv6`, `comment`
- `terraform/modules/cloudflare-proxied-subdomains/versions.tf` — required providers
- `terraform/.tflint.hcl` — tflint config for terraform/aws/cloudflare rulesets
- `.trivyignore` — empty placeholder
- `.pre-commit-config.yaml` — fmt/validate/tflint hooks

**Modified:**
- `terraform/versions.tf` — terraform/aws version pins
- `terraform/projects/hooks-fyi/versions.tf` — aws version
- `terraform/projects/rentivo/versions.tf` — aws version
- `.tool-versions` — terraform CLI version
- `terraform/.terraform.lock.hcl` — refreshed
- `terraform/variables.tf` — drop `cloudflare_account_id`
- `terraform/outputs.tf` — drop `cloudflare_account_id` passthrough
- `.github/workflows/pr-checks.yml` — bump TF version, drop `TF_VAR_cloudflare_account_id`, add tflint & trivy jobs, update aggregator
- `.github/workflows/terraform-apply.yml` — bump TF version, drop `TF_VAR_cloudflare_account_id`, add fmt-check step
- `terraform/projects/hooks-fyi/cloudflare.tf` — call new module + `moved` blocks
- `terraform/projects/rentivo/cloudflare.tf` — call new module + `moved` blocks
- `terraform/projects/joy-living/cloudflare.tf` — call new module + `moved` blocks
- `terraform/projects/eic-seminarios/cloudflare.tf` — call new module for proxied subset, leave unproxied inline
- `terraform/projects/jorgejunior/cloudflare.tf` — call new module twice (one per zone), leave MX/Vercel inline
- `README.md` — local-dev section, dead-code & layout updates
- `docs/ARCHITECTURE.md` — module documentation, CI/CD section update, drop `CLOUDFLARE_ACCOUNT_ID` row

---

## PR 1 — Version bumps (Tasks 1–4)

### Task 1: Bump Terraform required_version and CLI version

**Files:**
- Modify: `terraform/versions.tf:1-14`
- Modify: `.tool-versions:1`
- Modify: `.github/workflows/pr-checks.yml:58` (the `terraform_version: 1.9.8` line)
- Modify: `.github/workflows/terraform-apply.yml:44` (the `terraform_version: 1.9.8` line)

- [ ] **Step 1: Create branch**

```bash
git checkout main
git pull --ff-only
git checkout -b polish/01-version-bumps
```

- [ ] **Step 2: Update `terraform/versions.tf`**

Replace the file contents with:

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}
```

- [ ] **Step 3: Update `.tool-versions`**

Replace the file contents with:

```
terraform 1.10.5
```

- [ ] **Step 4: Update `terraform_version` in `pr-checks.yml`**

In `.github/workflows/pr-checks.yml`, change:

```yaml
          terraform_version: 1.9.8
```

to:

```yaml
          terraform_version: 1.10.5
```

- [ ] **Step 5: Update `terraform_version` in `terraform-apply.yml`**

In `.github/workflows/terraform-apply.yml`, change:

```yaml
          terraform_version: 1.9.8
```

to:

```yaml
          terraform_version: 1.10.5
```

- [ ] **Step 6: Validate locally**

Run:

```bash
cd terraform && terraform fmt -check -recursive && cd ..
```

Expected: exit 0, no output.

- [ ] **Step 7: Commit**

```bash
git add terraform/versions.tf .tool-versions \
  .github/workflows/pr-checks.yml \
  .github/workflows/terraform-apply.yml
git commit -m "chore(tf): bump Terraform to 1.10.5 and AWS provider to ~> 5.70"
```

---

### Task 2: Bump AWS provider pin in per-project versions.tf

**Files:**
- Modify: `terraform/projects/hooks-fyi/versions.tf:1-12`
- Modify: `terraform/projects/rentivo/versions.tf:1-12`

(`joy-living`, `jorgejunior`, `eic-seminarios` declare only `cloudflare` and don't need a bump.)

- [ ] **Step 1: Update `terraform/projects/hooks-fyi/versions.tf`**

Replace the file contents with:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}
```

- [ ] **Step 2: Update `terraform/projects/rentivo/versions.tf`**

Replace the file contents with:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}
```

- [ ] **Step 3: Validate locally**

```bash
cd terraform && terraform fmt -check -recursive && cd ..
```

Expected: exit 0, no output.

- [ ] **Step 4: Commit**

```bash
git add terraform/projects/hooks-fyi/versions.tf terraform/projects/rentivo/versions.tf
git commit -m "chore(tf): bump AWS provider to ~> 5.70 in project modules"
```

---

### Task 3: Refresh provider lockfile

**Files:**
- Modify: `terraform/.terraform.lock.hcl`

- [ ] **Step 1: Re-init with upgrade (locally — needs AWS creds for backend, or use `-backend=false`)**

```bash
cd terraform
terraform init -upgrade -backend=false
```

Expected: terraform downloads new provider versions and rewrites `.terraform.lock.hcl`. The `aws` provider should now resolve to `5.70.x` (latest matching `~> 5.70`); `cloudflare` should remain on the latest `4.40.x`.

- [ ] **Step 2: Validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Inspect lockfile diff**

```bash
git diff terraform/.terraform.lock.hcl
```

Expected: only `version` and `hashes` blocks for `hashicorp/aws` change. `cloudflare/cloudflare` may also see hash refresh — that's fine.

- [ ] **Step 4: Commit**

```bash
cd ..
git add terraform/.terraform.lock.hcl
git commit -m "chore(tf): refresh provider lockfile after AWS bump"
```

---

### Task 4: Open PR-1, verify no-op plan, merge

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin polish/01-version-bumps
gh pr create --title "chore(tf): bump Terraform 1.10.5 + AWS provider ~> 5.70" --body "$(cat <<'EOF'
## Summary
- Bump `required_version` to `>= 1.10.0, < 2.0.0` and CI/asdf to `1.10.5`.
- Bump AWS provider to `~> 5.70` in root and project modules.
- Cloudflare provider unchanged (4→5 is a separate effort).
- Refreshed `.terraform.lock.hcl`.

Spec: docs/superpowers/specs/2026-05-02-polish-repo-design.md (PR 1 of 5)

## Test plan
- [ ] CI plan workflow shows `0 to add, 0 to change, 0 to destroy`
- [ ] CI plan workflow runs on the new Terraform version (1.10.5)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Wait for `pr-checks` to complete**

Run:

```bash
gh pr checks --watch
```

Expected: `pr-checks / terraform-plan` passes; the plan PR comment shows `0 to add, 0 to change, 0 to destroy`.

- [ ] **Step 3: Merge**

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 4: Verify apply succeeded on `main`**

```bash
git checkout main && git pull --ff-only
gh run list --workflow=terraform-apply.yml --limit 1
```

Expected: latest apply run is `success`. If `failed`, do not proceed to PR 2 — investigate.

---

## PR 2 — Dead code removal (Tasks 5–8)

### Task 5: Remove `cloudflare_account_id` from Terraform

**Files:**
- Modify: `terraform/variables.tf:17-20` (delete the variable block)
- Modify: `terraform/outputs.tf:100-103` (delete the output block)

- [ ] **Step 1: Create branch**

```bash
git checkout main && git pull --ff-only
git checkout -b polish/02-dead-code
```

- [ ] **Step 2: Edit `terraform/variables.tf`**

Replace the file contents with:

```hcl
variable "aws_region" {
  description = "AWS region for all resources in this configuration."
  type        = string
  default     = "us-east-1"
}

variable "server_ipv4" {
  description = "IPv4 of the shared upstream server proxied by Cloudflare for A records. Sourced from TF_VAR_server_ipv4 in CI."
  type        = string
}

variable "server_ipv6" {
  description = "IPv6 of the shared upstream server proxied by Cloudflare for AAAA records. Sourced from TF_VAR_server_ipv6 in CI."
  type        = string
}
```

- [ ] **Step 3: Edit `terraform/outputs.tf` — remove the trailing `cloudflare_account_id` output**

Delete these lines from the bottom of the file:

```hcl
output "cloudflare_account_id" {
  description = "Cloudflare account ID (passthrough from var.cloudflare_account_id)."
  value       = var.cloudflare_account_id
}
```

The previous output (`output "joy_living_zone_id"`) becomes the new last block.

- [ ] **Step 4: Validate locally**

```bash
cd terraform
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
cd ..
```

Expected: `Success! The configuration is valid.` and `fmt` exit 0.

- [ ] **Step 5: Commit**

```bash
git add terraform/variables.tf terraform/outputs.tf
git commit -m "refactor(tf): drop unused cloudflare_account_id var and output"
```

---

### Task 6: Remove `CLOUDFLARE_ACCOUNT_ID` from CI workflows

**Files:**
- Modify: `.github/workflows/pr-checks.yml:43`
- Modify: `.github/workflows/terraform-apply.yml:29`

- [ ] **Step 1: Edit `pr-checks.yml`**

In `.github/workflows/pr-checks.yml`, locate the `env:` block under the `terraform-plan` job (currently around lines 39–43). Delete the line:

```yaml
      TF_VAR_cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
```

The `env:` block should now end with `TF_VAR_server_ipv6`.

- [ ] **Step 2: Edit `terraform-apply.yml`**

In `.github/workflows/terraform-apply.yml`, locate the `env:` block under the `apply` job (currently around lines 25–29). Delete the line:

```yaml
      TF_VAR_cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
```

The `env:` block should now end with `TF_VAR_server_ipv6`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/pr-checks.yml .github/workflows/terraform-apply.yml
git commit -m "ci: drop TF_VAR_cloudflare_account_id (variable removed)"
```

---

### Task 7: Remove `CLOUDFLARE_ACCOUNT_ID` from docs

**Files:**
- Modify: `README.md:18-19`
- Modify: `docs/ARCHITECTURE.md:117`

- [ ] **Step 1: Edit `README.md`**

Find this section (currently around lines 17–19):

```markdown
3. **Configure GitHub repo variables:**
   - `SERVER_IPV4`, `SERVER_IPV6` — origin server IPs proxied by Cloudflare
   - `CLOUDFLARE_ACCOUNT_ID`
```

Replace with:

```markdown
3. **Configure GitHub repo variables:**
   - `SERVER_IPV4`, `SERVER_IPV6` — origin server IPs proxied by Cloudflare
```

- [ ] **Step 2: Edit `docs/ARCHITECTURE.md`**

Find the Cloudflare authentication table (currently around lines 113–117):

```markdown
| Secret / Var | Purpose |
|--------------|---------|
| `CLOUDFLARE_API_TOKEN` (secret) | Cloudflare API token consumed by the cloudflare provider |
| `SERVER_IPV4` (var)             | Origin IPv4 used by all proxied A records |
| `SERVER_IPV6` (var)             | Origin IPv6 used by all proxied AAAA records |
| `CLOUDFLARE_ACCOUNT_ID` (var)   | Cloudflare account ID (currently passthrough output only) |
```

Replace with:

```markdown
| Secret / Var | Purpose |
|--------------|---------|
| `CLOUDFLARE_API_TOKEN` (secret) | Cloudflare API token consumed by the cloudflare provider |
| `SERVER_IPV4` (var)             | Origin IPv4 used by all proxied A records |
| `SERVER_IPV6` (var)             | Origin IPv6 used by all proxied AAAA records |
```

- [ ] **Step 3: Commit**

```bash
git add README.md docs/ARCHITECTURE.md
git commit -m "docs: drop CLOUDFLARE_ACCOUNT_ID references"
```

---

### Task 8: Open PR-2, verify no-op plan, merge

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin polish/02-dead-code
gh pr create --title "refactor: drop unused cloudflare_account_id" --body "$(cat <<'EOF'
## Summary
- Removes the `cloudflare_account_id` Terraform variable and passthrough output.
- Drops the corresponding `TF_VAR_cloudflare_account_id` env wiring in both workflows.
- Removes documentation references in README and ARCHITECTURE.

The variable was never consumed by any resource. The repo-level GitHub variable `CLOUDFLARE_ACCOUNT_ID` can stay set; it's now just unreferenced.

Spec: docs/superpowers/specs/2026-05-02-polish-repo-design.md (PR 2 of 5)

## Test plan
- [ ] CI plan shows `0 to add, 0 to change, 0 to destroy`
- [ ] CI plan job no longer references `TF_VAR_cloudflare_account_id`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Watch CI and verify no-op plan**

```bash
gh pr checks --watch
```

Expected: plan PR comment shows `0 to add, 0 to change, 0 to destroy`.

- [ ] **Step 3: Merge**

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 4: Verify apply succeeded on `main`**

```bash
git checkout main && git pull --ff-only
gh run list --workflow=terraform-apply.yml --limit 1
```

Expected: latest apply run is `success`.

---

## PR 3 — DRY: cloudflare-proxied-subdomains module (Tasks 9–15)

### Task 9: Create the `cloudflare-proxied-subdomains` module

**Files:**
- Create: `terraform/modules/cloudflare-proxied-subdomains/variables.tf`
- Create: `terraform/modules/cloudflare-proxied-subdomains/main.tf`
- Create: `terraform/modules/cloudflare-proxied-subdomains/versions.tf`

- [ ] **Step 1: Create branch**

```bash
git checkout main && git pull --ff-only
git checkout -b polish/03-cf-proxied-subdomains-module
```

- [ ] **Step 2: Create the module directory**

```bash
mkdir -p terraform/modules/cloudflare-proxied-subdomains
```

- [ ] **Step 3: Write `terraform/modules/cloudflare-proxied-subdomains/variables.tf`**

```hcl
variable "zone_id" {
  description = "Cloudflare zone ID that owns the records."
  type        = string
}

variable "subdomains" {
  description = "Set of subdomain names (e.g. [\"@\", \"www\"]) to create proxied A and AAAA records for."
  type        = set(string)
}

variable "ipv4" {
  description = "Origin IPv4 address used as the A record content."
  type        = string
}

variable "ipv6" {
  description = "Origin IPv6 address used as the AAAA record content."
  type        = string
}

variable "comment" {
  description = "Comment attached to each emitted record."
  type        = string
  default     = "Terraform managed record"
}
```

- [ ] **Step 4: Write `terraform/modules/cloudflare-proxied-subdomains/main.tf`**

```hcl
resource "cloudflare_record" "proxied_a" {
  for_each = var.subdomains

  zone_id = var.zone_id
  name    = each.value
  type    = "A"
  content = var.ipv4
  proxied = true
  comment = var.comment
}

resource "cloudflare_record" "proxied_aaaa" {
  for_each = var.subdomains

  zone_id = var.zone_id
  name    = each.value
  type    = "AAAA"
  content = var.ipv6
  proxied = true
  comment = var.comment
}
```

- [ ] **Step 5: Write `terraform/modules/cloudflare-proxied-subdomains/versions.tf`**

```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}
```

- [ ] **Step 6: Format and commit**

```bash
cd terraform && terraform fmt -recursive && cd ..
git add terraform/modules/cloudflare-proxied-subdomains/
git commit -m "feat(tf/modules): add cloudflare-proxied-subdomains primitive"
```

---

### Task 10: Migrate `hooks-fyi` to the module

**Files:**
- Modify: `terraform/projects/hooks-fyi/cloudflare.tf`

- [ ] **Step 1: Replace `terraform/projects/hooks-fyi/cloudflare.tf` contents with**

```hcl
data "cloudflare_zone" "hooks_fyi" {
  name = "hooks.fyi"
}

module "cf_proxied_hooks_fyi" {
  source = "../../modules/cloudflare-proxied-subdomains"

  zone_id    = data.cloudflare_zone.hooks_fyi.id
  subdomains = toset(["@", "www"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.hooks_fyi_a
  to   = module.cf_proxied_hooks_fyi.cloudflare_record.proxied_a
}

moved {
  from = cloudflare_record.hooks_fyi_aaaa
  to   = module.cf_proxied_hooks_fyi.cloudflare_record.proxied_aaaa
}

output "hooks_fyi_zone_id" {
  description = "Cloudflare zone ID for hooks.fyi."
  value       = data.cloudflare_zone.hooks_fyi.id
}
```

- [ ] **Step 2: Validate locally**

```bash
cd terraform
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
cd ..
```

Expected: `Success! The configuration is valid.` and `fmt` exit 0.

- [ ] **Step 3: Commit**

```bash
git add terraform/projects/hooks-fyi/cloudflare.tf
git commit -m "refactor(tf/hooks-fyi): use cloudflare-proxied-subdomains module"
```

---

### Task 11: Migrate `rentivo` to the module

**Files:**
- Modify: `terraform/projects/rentivo/cloudflare.tf`

- [ ] **Step 1: Replace `terraform/projects/rentivo/cloudflare.tf` contents with**

```hcl
data "cloudflare_zone" "rentivo" {
  name = local.rentivo_domain
}

module "cf_proxied_rentivo" {
  source = "../../modules/cloudflare-proxied-subdomains"

  zone_id    = data.cloudflare_zone.rentivo.id
  subdomains = toset(["@", "www"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.rentivo_a
  to   = module.cf_proxied_rentivo.cloudflare_record.proxied_a
}

moved {
  from = cloudflare_record.rentivo_aaaa
  to   = module.cf_proxied_rentivo.cloudflare_record.proxied_aaaa
}

resource "cloudflare_record" "rentivo_dmarc" {
  zone_id = data.cloudflare_zone.rentivo.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=none;"
  comment = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.rentivo.dkim_tokens)

  zone_id = data.cloudflare_zone.rentivo.id
  name    = "${each.value}._domainkey"
  type    = "CNAME"
  content = "${each.value}.dkim.amazonses.com"
  proxied = false
  comment = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_mail_mx" {
  zone_id  = data.cloudflare_zone.rentivo.id
  name     = "mail"
  type     = "MX"
  content  = "feedback-smtp.us-east-1.amazonses.com"
  priority = 10
  comment  = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_mail_spf" {
  zone_id = data.cloudflare_zone.rentivo.id
  name    = "mail"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  comment = "Terraform managed record"
}

output "rentivo_zone_id" {
  description = "Cloudflare zone ID for rentivo.com.br."
  value       = data.cloudflare_zone.rentivo.id
}
```

(`local.rentivo_domain` is defined in `terraform/projects/rentivo/ses.tf` and remains there.)

- [ ] **Step 2: Validate locally**

```bash
cd terraform
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
cd ..
```

Expected: validation success, fmt clean.

- [ ] **Step 3: Commit**

```bash
git add terraform/projects/rentivo/cloudflare.tf
git commit -m "refactor(tf/rentivo): use cloudflare-proxied-subdomains module"
```

---

### Task 12: Migrate `joy-living` to the module

**Files:**
- Modify: `terraform/projects/joy-living/cloudflare.tf`

- [ ] **Step 1: Replace `terraform/projects/joy-living/cloudflare.tf` contents with**

```hcl
data "cloudflare_zone" "joy_living" {
  name = "joyliving.com.br"
}

module "cf_proxied_joy_living" {
  source = "../../modules/cloudflare-proxied-subdomains"

  zone_id    = data.cloudflare_zone.joy_living.id
  subdomains = toset(["@", "www", "api"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.joy_living_a
  to   = module.cf_proxied_joy_living.cloudflare_record.proxied_a
}

moved {
  from = cloudflare_record.joy_living_aaaa
  to   = module.cf_proxied_joy_living.cloudflare_record.proxied_aaaa
}

output "joy_living_zone_id" {
  description = "Cloudflare zone ID for joyliving.com.br."
  value       = data.cloudflare_zone.joy_living.id
}
```

- [ ] **Step 2: Validate locally**

```bash
cd terraform
terraform validate
terraform fmt -check -recursive
cd ..
```

Expected: validation success, fmt clean.

- [ ] **Step 3: Commit**

```bash
git add terraform/projects/joy-living/cloudflare.tf
git commit -m "refactor(tf/joy-living): use cloudflare-proxied-subdomains module"
```

---

### Task 13: Migrate `eic-seminarios` (proxied subset only) to the module

**Files:**
- Modify: `terraform/projects/eic-seminarios/cloudflare.tf`

The unproxied `s3-beta` records keep their existing `cloudflare_record.eic_seminarios_a_unproxied` / `..._aaaa_unproxied` resource blocks because they have a different `proxied` value and a different comment.

- [ ] **Step 1: Replace `terraform/projects/eic-seminarios/cloudflare.tf` contents with**

```hcl
data "cloudflare_zone" "eic_seminarios" {
  name = "eic-seminarios.com"
}

module "cf_proxied_eic_seminarios" {
  source = "../../modules/cloudflare-proxied-subdomains"

  zone_id    = data.cloudflare_zone.eic_seminarios.id
  subdomains = toset(["beta", "mail-beta", "console-s3-beta"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.eic_seminarios_a
  to   = module.cf_proxied_eic_seminarios.cloudflare_record.proxied_a
}

moved {
  from = cloudflare_record.eic_seminarios_aaaa
  to   = module.cf_proxied_eic_seminarios.cloudflare_record.proxied_aaaa
}

locals {
  eic_seminarios_unproxied_subdomains = toset(["s3-beta"])
}

resource "cloudflare_record" "eic_seminarios_a_unproxied" {
  for_each = local.eic_seminarios_unproxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = false
  comment = "Terraform managed record (DNS-only: MinIO S3 API needs unproxied for SigV4)"
}

resource "cloudflare_record" "eic_seminarios_aaaa_unproxied" {
  for_each = local.eic_seminarios_unproxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = false
  comment = "Terraform managed record (DNS-only: MinIO S3 API needs unproxied for SigV4)"
}

output "eic_seminarios_zone_id" {
  description = "Cloudflare zone ID for eic-seminarios.com."
  value       = data.cloudflare_zone.eic_seminarios.id
}
```

- [ ] **Step 2: Validate locally**

```bash
cd terraform
terraform validate
terraform fmt -check -recursive
cd ..
```

Expected: validation success, fmt clean.

- [ ] **Step 3: Commit**

```bash
git add terraform/projects/eic-seminarios/cloudflare.tf
git commit -m "refactor(tf/eic-seminarios): use cloudflare-proxied-subdomains module"
```

---

### Task 14: Migrate `jorgejunior` (both zones) to the module

**Files:**
- Modify: `terraform/projects/jorgejunior/cloudflare.tf`

The MX records, the j-jr.app Vercel CNAMEs, and the zone data sources stay inline.

- [ ] **Step 1: Replace `terraform/projects/jorgejunior/cloudflare.tf` contents with**

```hcl
data "cloudflare_zone" "jorgejunior_dev" {
  name = "jorgejunior.dev"
}

data "cloudflare_zone" "j_jr_app" {
  name = "j-jr.app"
}

locals {
  vercel_cname_target = "cname.vercel-dns.com"

  jorgejunior_dev_mx_records = {
    bounces_ses = {
      name     = "bounces"
      content  = "feedback-smtp.sa-east-1.amazonses.com"
      priority = 10
    }
    mg_mailgun_a = {
      name     = "mg"
      content  = "mxa.mailgun.org"
      priority = 10
    }
    mg_mailgun_b = {
      name     = "mg"
      content  = "mxb.mailgun.org"
      priority = 20
    }
  }

  j_jr_app_vercel_subdomains = toset([
    "worktrackr",
    "panela-magica",
  ])
}

module "cf_proxied_jorgejunior_dev" {
  source = "../../modules/cloudflare-proxied-subdomains"

  zone_id = data.cloudflare_zone.jorgejunior_dev.id
  subdomains = toset([
    "www", "@",
    "wheregoes",
    "api",
    "dns",
    "estimates",
    "exchange-register",
    "me",
    "meta",
    "nova",
    "pdf",
    "s3", "s3-manager",
    "flux",
    "vscode",
    "land",
  ])
  ipv4 = var.server_ipv4
  ipv6 = var.server_ipv6
}

moved {
  from = cloudflare_record.jorgejunior_dev_a
  to   = module.cf_proxied_jorgejunior_dev.cloudflare_record.proxied_a
}

moved {
  from = cloudflare_record.jorgejunior_dev_aaaa
  to   = module.cf_proxied_jorgejunior_dev.cloudflare_record.proxied_aaaa
}

module "cf_proxied_j_jr_app" {
  source = "../../modules/cloudflare-proxied-subdomains"

  zone_id = data.cloudflare_zone.j_jr_app.id
  subdomains = toset([
    "@", "www",
    "panela-magica-api", "tourquest",
    "wheregoes-api", "wheregoes",
    "yt",
    "flux",
  ])
  ipv4 = var.server_ipv4
  ipv6 = var.server_ipv6
}

moved {
  from = cloudflare_record.j_jr_app_a
  to   = module.cf_proxied_j_jr_app.cloudflare_record.proxied_a
}

moved {
  from = cloudflare_record.j_jr_app_aaaa
  to   = module.cf_proxied_j_jr_app.cloudflare_record.proxied_aaaa
}

resource "cloudflare_record" "jorgejunior_dev_mx" {
  for_each = local.jorgejunior_dev_mx_records

  zone_id  = data.cloudflare_zone.jorgejunior_dev.id
  name     = each.value.name
  type     = "MX"
  content  = each.value.content
  priority = each.value.priority
  comment  = "Terraform managed record"
}

resource "cloudflare_record" "j_jr_app_vercel" {
  for_each = local.j_jr_app_vercel_subdomains

  zone_id = data.cloudflare_zone.j_jr_app.id
  name    = each.value
  type    = "CNAME"
  content = local.vercel_cname_target
  proxied = false
  comment = "Terraform managed record"
}

output "jorgejunior_dev_zone_id" {
  description = "Cloudflare zone ID for jorgejunior.dev."
  value       = data.cloudflare_zone.jorgejunior_dev.id
}

output "j_jr_app_zone_id" {
  description = "Cloudflare zone ID for j-jr.app."
  value       = data.cloudflare_zone.j_jr_app.id
}
```

- [ ] **Step 2: Validate locally**

```bash
cd terraform
terraform validate
terraform fmt -check -recursive
cd ..
```

Expected: validation success, fmt clean.

- [ ] **Step 3: Commit**

```bash
git add terraform/projects/jorgejunior/cloudflare.tf
git commit -m "refactor(tf/jorgejunior): use cloudflare-proxied-subdomains module for both zones"
```

---

### Task 15: Open PR-3, verify no-op plan, merge

This PR is the highest-risk one. Verify the plan PR comment carefully before merging.

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin polish/03-cf-proxied-subdomains-module
gh pr create --title "refactor(tf): extract cloudflare-proxied-subdomains module" --body "$(cat <<'EOF'
## Summary
- New child module `terraform/modules/cloudflare-proxied-subdomains` emits the proxied A+AAAA pair given `zone_id`, `subdomains`, `ipv4`, `ipv6`.
- All five projects switch to it for the proxied A/AAAA pattern.
- `moved {}` blocks preserve state for every for_each instance — plan must be a no-op.
- MX/TXT/DKIM/Vercel CNAMEs and the eic-seminarios unproxied `s3-beta` records stay inline.

Spec: docs/superpowers/specs/2026-05-02-polish-repo-design.md (PR 3 of 5)

## Test plan
- [ ] CI plan PR comment shows `0 to add, 0 to change, 0 to destroy`
- [ ] No `+`/`-` lines for any `cloudflare_record.*` in the plan output
- [ ] `module.cf_proxied_*` shows up in plan as state-only refactor (move) lines

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Watch CI and inspect plan**

```bash
gh pr checks --watch
```

Then read the PR comment posted by the plan workflow.

Expected:
- Resource counts: `Plan: 0 to add, 0 to change, 0 to destroy.`
- Every `cloudflare_record.*` instance in `eic_seminarios`, `hooks_fyi`, `j_jr_app`, `jorgejunior_dev`, `joy_living`, and `rentivo` (proxied A/AAAA only) appears as a state-only "moved" entry, not as a destroy/recreate.

If the plan shows ANY destroy or create on a proxied A/AAAA record: stop, do not merge. The most likely cause is a typo in a `moved` `to =` address or a `subdomains` set element that doesn't match the original `local.<x>_proxied_subdomains`.

- [ ] **Step 3: Merge**

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 4: Verify apply succeeded on `main`**

```bash
git checkout main && git pull --ff-only
gh run list --workflow=terraform-apply.yml --limit 1
```

Expected: latest apply run is `success` and reports no resource changes.

---

## PR 4 — CI hardening (Tasks 16–22)

### Task 16: Add tflint config

**Files:**
- Create: `terraform/.tflint.hcl`

- [ ] **Step 1: Create branch**

```bash
git checkout main && git pull --ff-only
git checkout -b polish/04-ci-hardening
```

- [ ] **Step 2: Write `terraform/.tflint.hcl`**

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

(No public Cloudflare ruleset is published as a tflint plugin; the built-in `terraform` ruleset covers generic checks.)

- [ ] **Step 3: Commit**

```bash
git add terraform/.tflint.hcl
git commit -m "ci: add tflint config (terraform + aws rulesets)"
```

---

### Task 17: Add `tflint` job to `pr-checks.yml`

**Files:**
- Modify: `.github/workflows/pr-checks.yml`

- [ ] **Step 1: Insert the `tflint` job after the existing `terraform-plan` job**

In `.github/workflows/pr-checks.yml`, after the `terraform-plan` job block ends (currently around line 126, just before the `plan:` aggregator), insert:

```yaml
  tflint:
    name: tflint
    needs: changes
    if: needs.changes.outputs.terraform == 'true'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup tflint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.55.0

      - name: tflint --init
        run: tflint --init

      - name: tflint
        run: tflint --recursive --format=compact
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/pr-checks.yml
git commit -m "ci: add tflint job to pr-checks"
```

---

### Task 18: Add `trivy-config` job to `pr-checks.yml`

**Files:**
- Modify: `.github/workflows/pr-checks.yml`
- Create: `.trivyignore`

- [ ] **Step 1: Create empty `.trivyignore` at repo root**

```
# Add CVE/check IDs here with a one-line comment per entry explaining why suppressed.
```

- [ ] **Step 2: Insert the `trivy-config` job after `tflint` in `pr-checks.yml`**

```yaml
  trivy-config:
    name: trivy-config
    needs: changes
    if: needs.changes.outputs.terraform == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Trivy config scan
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: config
          scan-ref: terraform/
          severity: HIGH,CRITICAL
          exit-code: "1"
          ignore-unfixed: true
          trivyignores: .trivyignore
```

- [ ] **Step 3: Update the `plan` aggregator job to require the new jobs**

Find the `plan:` job at the bottom of `pr-checks.yml` (currently around line 128). Replace its `needs:` and the verification script body:

```yaml
  plan:
    name: plan
    needs: [changes, terraform-plan, tflint, trivy-config]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Verify all required jobs succeeded or were skipped
        run: |
          changes_result="${{ needs.changes.result }}"
          plan_result="${{ needs.terraform-plan.result }}"
          tflint_result="${{ needs.tflint.result }}"
          trivy_result="${{ needs.trivy-config.result }}"
          echo "changes:      $changes_result"
          echo "terraform:    $plan_result"
          echo "tflint:       $tflint_result"
          echo "trivy-config: $trivy_result"
          if [[ "$changes_result" != "success" ]]; then
            echo "FAIL: changes detection did not succeed."
            exit 1
          fi
          for r in "$plan_result" "$tflint_result" "$trivy_result"; do
            if [[ "$r" != "success" && "$r" != "skipped" ]]; then
              echo "FAIL: a required job result was $r."
              exit 1
            fi
          done
          echo "PASS"
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/pr-checks.yml .trivyignore
git commit -m "ci: add trivy config scan and require it in pr-checks aggregator"
```

---

### Task 19: Add fmt-check step to `terraform-apply.yml`

**Files:**
- Modify: `.github/workflows/terraform-apply.yml`

- [ ] **Step 1: Insert a fmt-check step before `terraform init`**

In `.github/workflows/terraform-apply.yml`, after the `Setup Terraform` step (currently lines 41–45) and before `terraform init` (currently line 47), insert:

```yaml
      - name: terraform fmt -check
        run: terraform fmt -check -recursive
```

This step has no `continue-on-error`, so a `workflow_dispatch` apply on a fmt-drifted main will fail loudly.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/terraform-apply.yml
git commit -m "ci: enforce fmt on terraform-apply (covers workflow_dispatch path)"
```

---

### Task 20: Add `.pre-commit-config.yaml`

**Files:**
- Create: `.pre-commit-config.yaml`

- [ ] **Step 1: Write `.pre-commit-config.yaml`**

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.2
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
        args:
          - --hook-config=--retry-once-with-cleanup=true
      - id: terraform_tflint
        args:
          - --args=--recursive
          - --args=--format=compact
```

- [ ] **Step 2: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "chore: add pre-commit config (fmt, validate, tflint)"
```

---

### Task 21: Add local-dev pointer to README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Append a `## Local development` section after the `## Layout` section in `README.md`**

```markdown

## Local development

Optional but recommended: install [pre-commit](https://pre-commit.com) so fmt/validate/tflint run on every commit.

```bash
brew install pre-commit
pre-commit install
```

The same checks (`terraform_fmt`, `terraform_validate`, `tflint`) plus a Trivy config scan run in CI on every PR.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add local-dev / pre-commit section to README"
```

---

### Task 22: Open PR-4, verify CI green, triage findings, merge

PR-4 is the first PR where the new `tflint` and `trivy-config` jobs run. They will likely surface findings on first encounter — that's expected.

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin polish/04-ci-hardening
gh pr create --title "ci: add tflint, trivy config scan, fmt-on-apply, and pre-commit" --body "$(cat <<'EOF'
## Summary
- Adds `tflint` PR job using terraform + aws rulesets.
- Adds `trivy config` PR job at HIGH/CRITICAL.
- Adds `terraform fmt -check` to the apply workflow (covers workflow_dispatch).
- Adds `.pre-commit-config.yaml` for local fmt/validate/tflint.
- Aggregator job now requires both new jobs to succeed (or skip).

First-run findings will be triaged in this PR — fixed inline if cheap, otherwise suppressed in `.tflint.hcl` / `.trivyignore` with a one-line rationale.

Spec: docs/superpowers/specs/2026-05-02-polish-repo-design.md (PR 4 of 5)

## Test plan
- [ ] `pr-checks / tflint` job runs and is green
- [ ] `pr-checks / trivy-config` job runs and is green
- [ ] `pr-checks / plan` aggregator passes
- [ ] `terraform fmt -check` step appears in the apply workflow definition

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Watch CI**

```bash
gh pr checks --watch
```

- [ ] **Step 3: Triage tflint findings**

If `tflint` fails, read its log:

```bash
gh run view --log-failed
```

For each finding:
- **If fixable cheaply (a few minutes)**: fix the `.tf` file in this branch and push.
- **If a deliberate choice we keep**: add a `rule "<rule_name>" { enabled = false }` block to `terraform/.tflint.hcl` with a `# why:` comment on the line above. Do NOT bulk-disable rulesets.

- [ ] **Step 4: Triage trivy-config findings**

If `trivy-config` fails, read its log. For each HIGH/CRITICAL finding:
- **Fix**: amend the relevant resource in this branch and push.
- **Suppress**: add the check ID to `.trivyignore` on its own line with a `# why:` comment above it.

A finding worth flagging for follow-up but not blocking this PR is a `# TODO(polish-followup):` comment in `.trivyignore`.

- [ ] **Step 5: Merge once green**

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 6: Verify apply succeeded on `main`**

```bash
git checkout main && git pull --ff-only
gh run list --workflow=terraform-apply.yml --limit 1
```

Expected: latest apply run is `success` (and now exercises the new fmt-check step).

---

## PR 5 — Documentation refresh (Tasks 23–25)

### Task 23: Update `docs/ARCHITECTURE.md`

**Files:**
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Update the **Repository layout** tree**

Find the existing tree (currently lines 9–28) and replace the `terraform/` subtree to include the `modules/` directory. The new tree:

```
.
├── .github/workflows/             # CI/CD entrypoints
├── terraform/                     # the one Terraform root module
│   ├── versions.tf                # required terraform / providers
│   ├── providers.tf               # AWS provider config + default tags
│   ├── backend.tf                 # remote state (S3 + DynamoDB)
│   ├── variables.tf               # root inputs
│   ├── outputs.tf                 # surfaces module outputs to the root
│   ├── main.tf                    # `module "<project>" { source = "./projects/<project>" }`
│   ├── modules/                   # shared primitive modules (small, reusable)
│   │   └── cloudflare-proxied-subdomains/
│   └── projects/
│       └── <project>/             # one child module per application/project
│           ├── s3.tf              # bucket(s) for this project
│           ├── iam.tf             # user(s) and policies for this project
│           └── outputs.tf         # outputs the root module re-exports
├── scripts/                       # one-off operational scripts
├── docs/                          # design + decision records
├── .pre-commit-config.yaml        # local fmt/validate/tflint
├── .tool-versions                 # tfenv / asdf hint (terraform version)
└── README.md                      # quick-start for humans
```

- [ ] **Step 2: Add a **Shared primitive modules** subsection**

After the existing **One root module, many project sub-modules** subsection (which ends at the trade-off paragraph, currently around line 39), insert:

```markdown
### Shared primitive modules

`terraform/modules/` holds small reusable building blocks distinct from per-project child modules under `terraform/projects/`. They're primitives — equivalent in role to `aws_s3_bucket_versioning` or `aws_s3_bucket_public_access_block` — not project boundaries.

Currently the only one is `cloudflare-proxied-subdomains`: given a Cloudflare zone, a set of subdomains, and an IPv4/IPv6 pair, it emits the proxied A and AAAA records. Used by every project that publishes proxied origin records (`hooks-fyi`, `rentivo`, `joy-living`, `eic-seminarios`, `jorgejunior` ×2 zones). MX, DKIM, and CNAME records remain inline in each project — they don't share the same shape.
```

- [ ] **Step 3: Update the **CI/CD flows** section**

Find the **Plan (on PR)** subsection (currently lines 125–133) and replace with:

```markdown
### Plan (on PR)
Trigger: `pull_request` targeting `main`, when `terraform/**` or workflow files change.

Three jobs run in parallel:
1. **terraform-plan** — `fmt -check`, `init`, `validate`, `plan -out=tfplan`, then posts the plan as a PR comment.
2. **tflint** — runs `tflint --recursive` against `terraform/` with the terraform + aws rulesets (`terraform/.tflint.hcl`).
3. **trivy-config** — `trivy config --severity HIGH,CRITICAL terraform/`. Suppressions live in `.trivyignore` with one-line rationales.

A final `plan` aggregator job requires all three to succeed (or be skipped via the paths-filter).
```

Find the **Apply (on merge / manual)** subsection (currently lines 135–146) and replace with:

```markdown
### Apply (on merge / manual)
Triggers:
- `push` to `main` when `terraform/**` or workflow files change.
- `workflow_dispatch` (manual run from the Actions tab).
1. Checkout
2. Configure AWS credentials
3. `terraform fmt -check -recursive` (no continue-on-error — manual runs can't bypass fmt)
4. `terraform init`
5. `terraform validate`
6. `terraform plan -no-color -out=tfplan`
7. `terraform apply -auto-approve tfplan`

A single `concurrency: terraform-apply` group prevents two simultaneous applies from racing the state lock.
```

- [ ] **Step 4: Commit**

```bash
git checkout main && git pull --ff-only
git checkout -b polish/05-docs-refresh
git add docs/ARCHITECTURE.md
git commit -m "docs(architecture): document modules/ tree, primitive modules, new CI jobs"
```

---

### Task 24: Tighten `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace `README.md` contents with**

```markdown
# infra-resources

Terraform-managed infrastructure for the `jorgejr568` ecosystem (AWS + Cloudflare DNS), applied via GitHub Actions.

> Full documentation lives in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). This README is a quick-start.

## Quick start

1. **Bootstrap the state backend (one-time, per AWS account):**
   ```bash
   ./scripts/bootstrap-backend.sh
   ```
2. **Configure GitHub secrets:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `CLOUDFLARE_API_TOKEN`
3. **Configure GitHub repo variables:**
   - `SERVER_IPV4`, `SERVER_IPV6` — origin server IPs proxied by Cloudflare
4. **Push to `main`** — the apply workflow runs automatically.
5. **For changes thereafter**, open a PR. The plan workflow comments the diff. Merge to apply.

## Local development

Optional but recommended: install [pre-commit](https://pre-commit.com) so fmt/validate/tflint run on every commit.

```bash
brew install pre-commit
pre-commit install
```

The same checks (`terraform_fmt`, `terraform_validate`, `tflint`) plus a Trivy config scan run in CI on every PR.

## Layout

- `terraform/projects/<project>/` — one Terraform child module per project. Projects: `eic-seminarios`, `hooks-fyi`, `jorgejunior` (jorgejunior.dev + j-jr.app), `joy-living`, `rentivo`.
- `terraform/modules/` — shared primitive modules (currently `cloudflare-proxied-subdomains`).
- `terraform/` — root module: `main.tf`, `providers.tf`, `versions.tf`, `backend.tf`, `outputs.tf`, `variables.tf`. One state for everything.
- `.github/workflows/` — `pr-checks.yml` (PR), `terraform-apply.yml` (main).
- `scripts/` — operational scripts (state backend bootstrap).
- `docs/` — architecture and decision docs, plus implementation plans under `docs/superpowers/plans/`.
```

(Net difference vs. current README: the layout now mentions `terraform/modules/`, the workflow filename is corrected to `pr-checks.yml`, and a `Local development` section is added.)

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs(readme): mention modules/, fix workflow filename, add local-dev section"
```

---

### Task 25: Open PR-5, merge

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin polish/05-docs-refresh
gh pr create --title "docs: refresh README and ARCHITECTURE post-polish" --body "$(cat <<'EOF'
## Summary
- README mentions `terraform/modules/`, fixes the workflow filename (`pr-checks.yml`), and gains a Local development section.
- ARCHITECTURE adds a Shared primitive modules subsection covering `cloudflare-proxied-subdomains`, updates the layout tree, and rewrites the CI/CD flows section to reflect the new tflint/trivy-config jobs and the fmt-check on apply.

Spec: docs/superpowers/specs/2026-05-02-polish-repo-design.md (PR 5 of 5, final)

## Test plan
- [ ] CI plan job stays green (no terraform changes in this PR)
- [ ] Rendered README and ARCHITECTURE read cleanly and don't reference removed/renamed items

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Watch CI**

```bash
gh pr checks --watch
```

Expected: `pr-checks / plan` is `success` or `skipped` (the paths-filter may skip the terraform jobs since only docs changed).

- [ ] **Step 3: Merge**

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 4: Final verification**

```bash
git checkout main && git pull --ff-only
gh run list --workflow=terraform-apply.yml --limit 1
```

Expected: most recent apply run is `success`.

---

## Final state

After all five PRs merge:
- Terraform `1.10.5`, AWS provider `~> 5.70`, Cloudflare provider `~> 4.40`.
- `var.cloudflare_account_id` and `TF_VAR_cloudflare_account_id` gone.
- `terraform/modules/cloudflare-proxied-subdomains/` consumed by all five projects (proxied A/AAAA only).
- PR jobs: `terraform-plan`, `tflint`, `trivy-config` + aggregator.
- Apply workflow runs `terraform fmt -check` before init.
- `.pre-commit-config.yaml` available for contributors.
- README and ARCHITECTURE.md describe the new shape.

No deployed AWS or Cloudflare resource is created, destroyed, or modified by this plan.
