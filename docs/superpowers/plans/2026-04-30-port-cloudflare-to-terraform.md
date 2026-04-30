# Port cloudflare-resources from Pulumi (Go) to Terraform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the standalone `cloudflare-resources/` Pulumi-Go program with native Terraform under `terraform/projects/`, reusing the existing root module + per-project provider pattern. After cutover, the Pulumi tree is deleted and the GitHub repo is ready to be renamed to `infra-resources`.

**Architecture:**
- Cloudflare DNS becomes a per-project concern. Existing AWS projects (`hooks-fyi`, `rentivo`) gain a `cloudflare.tf`. Three new CF-only projects are added: `jorgejunior` (groups `jorgejunior.dev` + `j-jr.app`), `eic-seminarios`, `joy-living`.
- The Pulumi `vistadamontanha.com.br` zone is **dropped** — the user no longer owns the domain. Records were 1× A + 1× AAAA (`ai`) + 1 Vercel CNAME (`chat`); they are not ported.
- The root module declares one Cloudflare provider (account-scoped, no aliases — Cloudflare doesn't have AWS-style provider-level tagging) and passes it down. AWS providers retain their per-project aliases.
- Three previously-Pulumi-encrypted values (`server:ipv4`, `server:ipv6`, `cf:accountId`) are not actually secret (they're published in public DNS); they become Terraform variables sourced from GitHub repo variables (`TF_VAR_*`), matching the existing `STACK_NAME`/secrets pattern.
- **Migration mode: greenfield (per user choice).** Before merge, `pulumi destroy` removes the existing records; on merge, `terraform apply` creates them fresh. Brief DNS gap is acceptable. No state import.

**Tech Stack:** Terraform 1.9.8, `cloudflare/cloudflare ~> 4.40` (4.x line — uses `cloudflare_record`; v5 introduced the `cloudflare_dns_record` rename and is not worth the churn here), existing `hashicorp/aws ~> 5.60`.

---

## File Structure

**New files:**
- `terraform/projects/hooks-fyi/cloudflare.tf` — hooks.fyi zone records.
- `terraform/projects/rentivo/cloudflare.tf` — rentivo.com.br zone records (DKIM CNAMEs wired to `aws_ses_domain_dkim.rentivo.dkim_tokens`, replacing Pulumi's hardcoded tokens).
- `terraform/projects/jorgejunior/versions.tf` — declare aws + cloudflare providers.
- `terraform/projects/jorgejunior/cloudflare.tf` — jorgejunior.dev + j-jr.app zone records.
- `terraform/projects/jorgejunior/variables.tf` — inputs (`server_ipv4`, `server_ipv6`).
- `terraform/projects/eic-seminarios/versions.tf`
- `terraform/projects/eic-seminarios/cloudflare.tf`
- `terraform/projects/eic-seminarios/variables.tf`
- `terraform/projects/joy-living/versions.tf`
- `terraform/projects/joy-living/cloudflare.tf`
- `terraform/projects/joy-living/variables.tf`

**Modified files:**
- `terraform/versions.tf` — add `cloudflare/cloudflare ~> 4.40`.
- `terraform/providers.tf` — add a single `cloudflare` provider block.
- `terraform/variables.tf` — add `server_ipv4`, `server_ipv6`, `cloudflare_account_id` (the third is unused by current records, but exporting it preserves the Pulumi `cloudflare-account-id` output).
- `terraform/main.tf` — wire new and existing modules, pass cloudflare provider + variables.
- `terraform/outputs.tf` — re-export zone IDs (mirrors Pulumi's `*-zone-id` exports).
- `terraform/projects/hooks-fyi/versions.tf` — add cloudflare provider requirement.
- `terraform/projects/hooks-fyi/variables.tf` (new in this project) — add `server_ipv4`, `server_ipv6`.
- `terraform/projects/rentivo/versions.tf` — add cloudflare provider requirement.
- `terraform/projects/rentivo/variables.tf` (new in this project) — add `server_ipv4`, `server_ipv6`.
- `.github/workflows/terraform-plan.yml` — pass `TF_VAR_*` and `CLOUDFLARE_API_TOKEN` env to plan steps.
- `.github/workflows/terraform-apply.yml` — same for apply.
- `README.md` — drop the AWS-only framing, mention Cloudflare DNS.
- `docs/ARCHITECTURE.md` — note Cloudflare DNS belongs to the project that owns the zone, document the three repo vars.

**Deleted files (final cutover task):**
- Entire `cloudflare-resources/` tree.

**Files NOT created:**
- No `cloudflare/` umbrella project. Per user instruction, records belong to the project that owns the zone.
- No reusable `terraform/modules/cloudflare-zone/` child module. Each project's CF config is small enough that an extra abstraction is YAGNI; revisit if a fifth zone joins.

---

### Task 1: Detach the nested `cloudflare-resources` git clone

**Files:**
- Delete: `cloudflare-resources/.git/`

We keep the rest of `cloudflare-resources/` in place for now — Tasks 4–9 reference its `.go` files as the spec for what records to create. The whole directory disappears in Task 13.

- [ ] **Step 1: Confirm working tree is clean**

Run: `git -C /Users/j/src/jorgejr568/aws-resources status --short`
Expected: empty output.

- [ ] **Step 2: Capture the inner repo's HEAD SHA for the commit message**

Run: `git -C /Users/j/src/jorgejr568/aws-resources/cloudflare-resources rev-parse HEAD`
Expected: 40-char SHA. Save it (referenced as `<INNER_HEAD_SHA>` below).

- [ ] **Step 3: Remove the inner `.git/` directory**

Run: `rm -rf /Users/j/src/jorgejr568/aws-resources/cloudflare-resources/.git`
Expected: exit 0, no output.

- [ ] **Step 4: Verify the inner clone is gone and content is now untracked**

Run: `test -d /Users/j/src/jorgejr568/aws-resources/cloudflare-resources/.git && echo "still there" || echo "gone"`
Expected: `gone`.

Run: `test -f /Users/j/src/jorgejr568/aws-resources/.gitmodules && echo "FOUND" || echo "absent"`
Expected: `absent`.

Run: `git -C /Users/j/src/jorgejr568/aws-resources status --short --untracked-files=normal cloudflare-resources/ | head -5`
Expected: lines starting with `??` (untracked files), not a single collapsed `?? cloudflare-resources/`. If it collapsed, that's still fine — `git add cloudflare-resources/` will work either way.

- [ ] **Step 5: Stage and commit the imported tree (it'll be deleted again in Task 13, but capturing it as a real commit gives a clean history of "the Pulumi version we ported from")**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add cloudflare-resources/
git commit -m "$(cat <<'EOF'
chore: import cloudflare-resources tree (pre-port snapshot)

Imported from jorgejr568/cloudflare-resources @ <INNER_HEAD_SHA>.
Inner .git/ removed. The Pulumi-Go program in this directory is the spec
for the upcoming Terraform port; it will be deleted at the end of the
port (Task 13) once the Terraform side replaces it.
EOF
)"
```

Replace `<INNER_HEAD_SHA>` with the value from Step 2 before running.

Expected: clean working tree afterwards.

---

### Task 2: Add Cloudflare provider to the root module

**Files:**
- Modify: `terraform/versions.tf`
- Modify: `terraform/providers.tf`

- [ ] **Step 1: Add the cloudflare provider requirement**

Use Edit on `terraform/versions.tf`:
- old_string:
  ```
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
- new_string:
  ```
  terraform {
    required_version = ">= 1.7.0, < 2.0.0"

    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.60"
      }
      cloudflare = {
        source  = "cloudflare/cloudflare"
        version = "~> 4.40"
      }
    }
  }
  ```

- [ ] **Step 2: Add the cloudflare provider block**

Use Edit on `terraform/providers.tf`. Append (the file currently ends at line 36 with the rentivo aws provider closing brace):
- old_string:
  ```
  provider "aws" {
    alias  = "rentivo"
    region = var.aws_region

    default_tags {
      tags = {
        ManagedBy = "terraform"
        Repo      = "aws-resources"
        Project   = "rentivo"
      }
    }
  }
  ```
- new_string:
  ```
  provider "aws" {
    alias  = "rentivo"
    region = var.aws_region

    default_tags {
      tags = {
        ManagedBy = "terraform"
        Repo      = "aws-resources"
        Project   = "rentivo"
      }
    }
  }

  provider "cloudflare" {
    # API token comes from CLOUDFLARE_API_TOKEN env var in CI; no per-project
    # alias because Cloudflare has no provider-level tagging concept.
  }
  ```

- [ ] **Step 3: Verify formatting**

Run: `cd /Users/j/src/jorgejr568/aws-resources/terraform && terraform fmt -check -recursive`
Expected: exit 0. If non-zero, run `terraform fmt -recursive` and re-check.

- [ ] **Step 4: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add terraform/versions.tf terraform/providers.tf
git commit -m "feat(tf): add cloudflare provider to root module"
```

---

### Task 3: Add the three new root-level variables

**Files:**
- Modify: `terraform/variables.tf`

These three were Pulumi `secure:` config values. They're not actually secret — `server:ipv4` and `server:ipv6` get published as A/AAAA records in public DNS, and the Cloudflare account ID is also non-sensitive. We model them as required variables with no defaults; values are supplied to CI via GitHub repo variables (`TF_VAR_server_ipv4`, etc.) in Task 12. This avoids committing the IPs while not pretending they're secrets.

- [ ] **Step 1: Add the variables**

Use Edit on `terraform/variables.tf`:
- old_string:
  ```
  variable "aws_region" {
    description = "AWS region for all resources in this configuration."
    type        = string
    default     = "us-east-1"
  }
  ```
- new_string:
  ```
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

  variable "cloudflare_account_id" {
    description = "Cloudflare account ID. Sourced from TF_VAR_cloudflare_account_id in CI. Currently re-exported as an output to mirror the previous Pulumi export; not consumed by any resource yet."
    type        = string
  }
  ```

- [ ] **Step 2: Verify**

Use the Read tool on `terraform/variables.tf`.
Expected: four `variable` blocks total (`aws_region`, `server_ipv4`, `server_ipv6`, `cloudflare_account_id`).

- [ ] **Step 3: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add terraform/variables.tf
git commit -m "feat(tf): add server IPs and cloudflare account id variables"
```

---

### Task 4: hooks-fyi — add cloudflare.tf

Spec (from `cloudflare-resources/records/hooks-fyi-records.go`):
- Zone: `hooks.fyi`
- Subdomains: `@`, `www` — both A + AAAA, **proxied=true**.

**Files:**
- Modify: `terraform/projects/hooks-fyi/versions.tf`
- Create: `terraform/projects/hooks-fyi/variables.tf`
- Create: `terraform/projects/hooks-fyi/cloudflare.tf`
- Modify: `terraform/main.tf` (to pass new variables)

- [ ] **Step 1: Add cloudflare provider requirement**

Use Edit on `terraform/projects/hooks-fyi/versions.tf`:
- old_string:
  ```
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.60"
      }
    }
  }
  ```
- new_string:
  ```
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.60"
      }
      cloudflare = {
        source  = "cloudflare/cloudflare"
        version = "~> 4.40"
      }
    }
  }
  ```

- [ ] **Step 2: Create the project's variables file**

Use Write to create `terraform/projects/hooks-fyi/variables.tf`:
```
variable "server_ipv4" {
  description = "Upstream server IPv4 for proxied A records."
  type        = string
}

variable "server_ipv6" {
  description = "Upstream server IPv6 for proxied AAAA records."
  type        = string
}
```

- [ ] **Step 3: Create cloudflare.tf**

Use Write to create `terraform/projects/hooks-fyi/cloudflare.tf`:
```
data "cloudflare_zone" "hooks_fyi" {
  name = "hooks.fyi"
}

locals {
  hooks_fyi_proxied_subdomains = toset(["@", "www"])
}

resource "cloudflare_record" "hooks_fyi_a" {
  for_each = local.hooks_fyi_proxied_subdomains

  zone_id = data.cloudflare_zone.hooks_fyi.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "hooks_fyi_aaaa" {
  for_each = local.hooks_fyi_proxied_subdomains

  zone_id = data.cloudflare_zone.hooks_fyi.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

output "hooks_fyi_zone_id" {
  description = "Cloudflare zone ID for hooks.fyi."
  value       = data.cloudflare_zone.hooks_fyi.id
}
```

- [ ] **Step 4: Wire variables through `terraform/main.tf`**

Use Edit on `terraform/main.tf`:
- old_string:
  ```
  module "hooks_fyi" {
    source = "./projects/hooks-fyi"

    providers = {
      aws = aws.hooks_fyi
    }
  }
  ```
- new_string:
  ```
  module "hooks_fyi" {
    source = "./projects/hooks-fyi"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      aws        = aws.hooks_fyi
      cloudflare = cloudflare
    }
  }
  ```

- [ ] **Step 5: Re-export the zone ID at the root**

Use Edit on `terraform/outputs.tf` (append at the end):
- old_string:
  ```
  output "rentivo_ses_dkim_tokens" {
    description = "SES DKIM tokens (publish three CNAMEs: <token>._domainkey.rentivo.com.br -> <token>.dkim.amazonses.com)."
    value       = module.rentivo.rentivo_ses_dkim_tokens
  }
  ```
- new_string:
  ```
  output "rentivo_ses_dkim_tokens" {
    description = "SES DKIM tokens (publish three CNAMEs: <token>._domainkey.rentivo.com.br -> <token>.dkim.amazonses.com)."
    value       = module.rentivo.rentivo_ses_dkim_tokens
  }

  output "hooks_fyi_zone_id" {
    description = "Cloudflare zone ID for hooks.fyi."
    value       = module.hooks_fyi.hooks_fyi_zone_id
  }

  output "cloudflare_account_id" {
    description = "Cloudflare account ID (passthrough from var.cloudflare_account_id)."
    value       = var.cloudflare_account_id
  }
  ```

- [ ] **Step 6: Verify**

Run: `cd /Users/j/src/jorgejr568/aws-resources/terraform && terraform fmt -check -recursive`
Expected: exit 0. If non-zero, run `terraform fmt -recursive`.

- [ ] **Step 7: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add terraform/projects/hooks-fyi/ terraform/main.tf terraform/outputs.tf
git commit -m "feat(tf): port hooks.fyi cloudflare records to terraform"
```

---

### Task 5: rentivo — add cloudflare.tf

Spec (from `cloudflare-resources/records/rentivo-com-br-records.go`):
- Zone: `rentivo.com.br`
- A + AAAA proxied: `@`, `www`
- TXT `_dmarc` → `v=DMARC1; p=none;`
- 3× CNAME `<token>._domainkey` → `<token>.dkim.amazonses.com`, **proxied=false**. Tokens were hardcoded in Pulumi but are actually `aws_ses_domain_dkim.rentivo.dkim_tokens` from `ses.tf` in this same project — wire them directly.
- MX 10 `mail` → `feedback-smtp.us-east-1.amazonses.com`
- TXT `mail` → `v=spf1 include:amazonses.com ~all`

Note: the existing Pulumi setup also outputs an SES `verification_token` from `aws_ses_domain_identity.rentivo` with the comment "Publish as TXT record at _amazonses.<domain>" — but Pulumi never actually publishes it. Faithful port = don't add it now. Track separately if needed.

**Files:**
- Modify: `terraform/projects/rentivo/versions.tf`
- Create: `terraform/projects/rentivo/variables.tf`
- Create: `terraform/projects/rentivo/cloudflare.tf`
- Modify: `terraform/main.tf`

- [ ] **Step 1: Add cloudflare provider requirement**

Use Edit on `terraform/projects/rentivo/versions.tf`:
- old_string:
  ```
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.60"
      }
    }
  }
  ```
- new_string:
  ```
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.60"
      }
      cloudflare = {
        source  = "cloudflare/cloudflare"
        version = "~> 4.40"
      }
    }
  }
  ```

- [ ] **Step 2: Create variables.tf**

Use Write to create `terraform/projects/rentivo/variables.tf`:
```
variable "server_ipv4" {
  description = "Upstream server IPv4 for proxied A records."
  type        = string
}

variable "server_ipv6" {
  description = "Upstream server IPv6 for proxied AAAA records."
  type        = string
}
```

- [ ] **Step 3: Create cloudflare.tf**

Use Write to create `terraform/projects/rentivo/cloudflare.tf`:
```
data "cloudflare_zone" "rentivo" {
  name = local.rentivo_domain
}

locals {
  rentivo_proxied_subdomains = toset(["@", "www"])
}

resource "cloudflare_record" "rentivo_a" {
  for_each = local.rentivo_proxied_subdomains

  zone_id = data.cloudflare_zone.rentivo.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_aaaa" {
  for_each = local.rentivo_proxied_subdomains

  zone_id = data.cloudflare_zone.rentivo.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
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

Note: `local.rentivo_domain` is already defined in `terraform/projects/rentivo/ses.tf` (`= "rentivo.com.br"`) — both files share the project's locals.

- [ ] **Step 4: Wire variables and provider through `terraform/main.tf`**

Use Edit on `terraform/main.tf`:
- old_string:
  ```
  module "rentivo" {
    source = "./projects/rentivo"

    providers = {
      aws = aws.rentivo
    }
  }
  ```
- new_string:
  ```
  module "rentivo" {
    source = "./projects/rentivo"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      aws        = aws.rentivo
      cloudflare = cloudflare
    }
  }
  ```

- [ ] **Step 5: Re-export the zone ID at the root**

Use Edit on `terraform/outputs.tf`:
- old_string:
  ```
  output "hooks_fyi_zone_id" {
    description = "Cloudflare zone ID for hooks.fyi."
    value       = module.hooks_fyi.hooks_fyi_zone_id
  }
  ```
- new_string:
  ```
  output "hooks_fyi_zone_id" {
    description = "Cloudflare zone ID for hooks.fyi."
    value       = module.hooks_fyi.hooks_fyi_zone_id
  }

  output "rentivo_zone_id" {
    description = "Cloudflare zone ID for rentivo.com.br."
    value       = module.rentivo.rentivo_zone_id
  }
  ```

- [ ] **Step 6: Verify formatting**

Run: `cd /Users/j/src/jorgejr568/aws-resources/terraform && terraform fmt -check -recursive`
Expected: exit 0. Run `terraform fmt -recursive` if drift.

- [ ] **Step 7: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add terraform/projects/rentivo/ terraform/main.tf terraform/outputs.tf
git commit -m "feat(tf): port rentivo cloudflare records (DKIM wired to SES output)"
```

---

### Task 6: jorgejunior — new project (jorgejunior.dev + j-jr.app)

Spec (from `cloudflare-resources/records/jorge-junior-dev-records.go` and `j-jr-app-records.go`):

`jorgejunior.dev`:
- A + AAAA proxied subdomains: `www`, `@`, `wheregoes`, `api`, `dns`, `estimates`, `exchange-register`, `me`, `meta`, `nova`, `pdf`, `s3`, `s3-manager`, `flux`, `vscode`, `land` (16 subdomains).
- MX 10 `bounces` → `feedback-smtp.sa-east-1.amazonses.com`
- MX 10 `mg` → `mxa.mailgun.org`
- MX 20 `mg` → `mxb.mailgun.org`

`j-jr.app`:
- A + AAAA proxied subdomains: `@`, `www`, `panela-magica-api`, `tourquest`, `wheregoes-api`, `wheregoes`, `yt`, `flux` (8 subdomains).
- Vercel CNAMEs (proxied=false, content=`cname.vercel-dns.com`): `worktrackr`, `panela-magica`.

**Files:**
- Create: `terraform/projects/jorgejunior/versions.tf`
- Create: `terraform/projects/jorgejunior/variables.tf`
- Create: `terraform/projects/jorgejunior/cloudflare.tf`
- Modify: `terraform/main.tf`
- Modify: `terraform/outputs.tf`

- [ ] **Step 1: Create versions.tf**

Use Write to create `terraform/projects/jorgejunior/versions.tf`:
```
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}
```

- [ ] **Step 2: Create variables.tf**

Use Write to create `terraform/projects/jorgejunior/variables.tf`:
```
variable "server_ipv4" {
  description = "Upstream server IPv4 for proxied A records."
  type        = string
}

variable "server_ipv6" {
  description = "Upstream server IPv6 for proxied AAAA records."
  type        = string
}
```

- [ ] **Step 3: Create cloudflare.tf**

Use Write to create `terraform/projects/jorgejunior/cloudflare.tf`:
```
data "cloudflare_zone" "jorgejunior_dev" {
  name = "jorgejunior.dev"
}

data "cloudflare_zone" "j_jr_app" {
  name = "j-jr.app"
}

locals {
  vercel_cname_target = "cname.vercel-dns.com"

  jorgejunior_dev_proxied_subdomains = toset([
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

  j_jr_app_proxied_subdomains = toset([
    "@", "www",
    "panela-magica-api", "tourquest",
    "wheregoes-api", "wheregoes",
    "yt",
    "flux",
  ])

  j_jr_app_vercel_subdomains = toset([
    "worktrackr",
    "panela-magica",
  ])

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
}

resource "cloudflare_record" "jorgejunior_dev_a" {
  for_each = local.jorgejunior_dev_proxied_subdomains

  zone_id = data.cloudflare_zone.jorgejunior_dev.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "jorgejunior_dev_aaaa" {
  for_each = local.jorgejunior_dev_proxied_subdomains

  zone_id = data.cloudflare_zone.jorgejunior_dev.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
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

resource "cloudflare_record" "j_jr_app_a" {
  for_each = local.j_jr_app_proxied_subdomains

  zone_id = data.cloudflare_zone.j_jr_app.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "j_jr_app_aaaa" {
  for_each = local.j_jr_app_proxied_subdomains

  zone_id = data.cloudflare_zone.j_jr_app.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
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

- [ ] **Step 4: Wire into root main.tf**

Use Edit on `terraform/main.tf` to append a new module block after the rentivo module:
- old_string:
  ```
  module "rentivo" {
    source = "./projects/rentivo"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      aws        = aws.rentivo
      cloudflare = cloudflare
    }
  }
  ```
- new_string:
  ```
  module "rentivo" {
    source = "./projects/rentivo"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      aws        = aws.rentivo
      cloudflare = cloudflare
    }
  }

  module "jorgejunior" {
    source = "./projects/jorgejunior"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      cloudflare = cloudflare
    }
  }
  ```

- [ ] **Step 5: Add zone-id outputs at root**

Use Edit on `terraform/outputs.tf`:
- old_string:
  ```
  output "rentivo_zone_id" {
    description = "Cloudflare zone ID for rentivo.com.br."
    value       = module.rentivo.rentivo_zone_id
  }
  ```
- new_string:
  ```
  output "rentivo_zone_id" {
    description = "Cloudflare zone ID for rentivo.com.br."
    value       = module.rentivo.rentivo_zone_id
  }

  output "jorgejunior_dev_zone_id" {
    description = "Cloudflare zone ID for jorgejunior.dev."
    value       = module.jorgejunior.jorgejunior_dev_zone_id
  }

  output "j_jr_app_zone_id" {
    description = "Cloudflare zone ID for j-jr.app."
    value       = module.jorgejunior.j_jr_app_zone_id
  }
  ```

- [ ] **Step 6: Verify**

Run: `cd /Users/j/src/jorgejr568/aws-resources/terraform && terraform fmt -check -recursive`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add terraform/projects/jorgejunior/ terraform/main.tf terraform/outputs.tf
git commit -m "feat(tf): add jorgejunior project (jorgejunior.dev + j-jr.app)"
```

---

### Task 7: eic-seminarios — new project

Spec (from `cloudflare-resources/records/eic-seminarios-records.go`):
- Zone: `eic-seminarios.com`
- A + AAAA proxied: `v2`.

**Files:**
- Create: `terraform/projects/eic-seminarios/versions.tf`
- Create: `terraform/projects/eic-seminarios/variables.tf`
- Create: `terraform/projects/eic-seminarios/cloudflare.tf`
- Modify: `terraform/main.tf`
- Modify: `terraform/outputs.tf`

- [ ] **Step 1: Create versions.tf**

Use Write to create `terraform/projects/eic-seminarios/versions.tf`:
```
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}
```

- [ ] **Step 2: Create variables.tf**

Use Write to create `terraform/projects/eic-seminarios/variables.tf`:
```
variable "server_ipv4" {
  description = "Upstream server IPv4 for proxied A records."
  type        = string
}

variable "server_ipv6" {
  description = "Upstream server IPv6 for proxied AAAA records."
  type        = string
}
```

- [ ] **Step 3: Create cloudflare.tf**

Use Write to create `terraform/projects/eic-seminarios/cloudflare.tf`:
```
data "cloudflare_zone" "eic_seminarios" {
  name = "eic-seminarios.com"
}

locals {
  eic_seminarios_proxied_subdomains = toset(["v2"])
}

resource "cloudflare_record" "eic_seminarios_a" {
  for_each = local.eic_seminarios_proxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "eic_seminarios_aaaa" {
  for_each = local.eic_seminarios_proxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

output "eic_seminarios_zone_id" {
  description = "Cloudflare zone ID for eic-seminarios.com."
  value       = data.cloudflare_zone.eic_seminarios.id
}
```

- [ ] **Step 4: Wire into root main.tf**

Use Edit on `terraform/main.tf`:
- old_string:
  ```
  module "jorgejunior" {
    source = "./projects/jorgejunior"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      cloudflare = cloudflare
    }
  }
  ```
- new_string:
  ```
  module "jorgejunior" {
    source = "./projects/jorgejunior"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      cloudflare = cloudflare
    }
  }

  module "eic_seminarios" {
    source = "./projects/eic-seminarios"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      cloudflare = cloudflare
    }
  }
  ```

- [ ] **Step 5: Add zone-id output at root**

Use Edit on `terraform/outputs.tf`:
- old_string:
  ```
  output "j_jr_app_zone_id" {
    description = "Cloudflare zone ID for j-jr.app."
    value       = module.jorgejunior.j_jr_app_zone_id
  }
  ```
- new_string:
  ```
  output "j_jr_app_zone_id" {
    description = "Cloudflare zone ID for j-jr.app."
    value       = module.jorgejunior.j_jr_app_zone_id
  }

  output "eic_seminarios_zone_id" {
    description = "Cloudflare zone ID for eic-seminarios.com."
    value       = module.eic_seminarios.eic_seminarios_zone_id
  }
  ```

- [ ] **Step 6: Verify**

Run: `cd /Users/j/src/jorgejr568/aws-resources/terraform && terraform fmt -check -recursive`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add terraform/projects/eic-seminarios/ terraform/main.tf terraform/outputs.tf
git commit -m "feat(tf): add eic-seminarios project (eic-seminarios.com)"
```

---

### Task 8: joy-living — new project

Spec (from `cloudflare-resources/records/joy-living-records.go`):
- Zone: `joyliving.com.br`
- A + AAAA proxied: `@`, `www`, `api`.

**Files:**
- Create: `terraform/projects/joy-living/versions.tf`
- Create: `terraform/projects/joy-living/variables.tf`
- Create: `terraform/projects/joy-living/cloudflare.tf`
- Modify: `terraform/main.tf`
- Modify: `terraform/outputs.tf`

- [ ] **Step 1: Create versions.tf**

Use Write to create `terraform/projects/joy-living/versions.tf`:
```
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}
```

- [ ] **Step 2: Create variables.tf**

Use Write to create `terraform/projects/joy-living/variables.tf`:
```
variable "server_ipv4" {
  description = "Upstream server IPv4 for proxied A records."
  type        = string
}

variable "server_ipv6" {
  description = "Upstream server IPv6 for proxied AAAA records."
  type        = string
}
```

- [ ] **Step 3: Create cloudflare.tf**

Use Write to create `terraform/projects/joy-living/cloudflare.tf`:
```
data "cloudflare_zone" "joy_living" {
  name = "joyliving.com.br"
}

locals {
  joy_living_proxied_subdomains = toset(["@", "www", "api"])
}

resource "cloudflare_record" "joy_living_a" {
  for_each = local.joy_living_proxied_subdomains

  zone_id = data.cloudflare_zone.joy_living.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "joy_living_aaaa" {
  for_each = local.joy_living_proxied_subdomains

  zone_id = data.cloudflare_zone.joy_living.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

output "joy_living_zone_id" {
  description = "Cloudflare zone ID for joyliving.com.br."
  value       = data.cloudflare_zone.joy_living.id
}
```

- [ ] **Step 4: Wire into root main.tf**

Use Edit on `terraform/main.tf`:
- old_string:
  ```
  module "eic_seminarios" {
    source = "./projects/eic-seminarios"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      cloudflare = cloudflare
    }
  }
  ```
- new_string:
  ```
  module "eic_seminarios" {
    source = "./projects/eic-seminarios"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      cloudflare = cloudflare
    }
  }

  module "joy_living" {
    source = "./projects/joy-living"

    server_ipv4 = var.server_ipv4
    server_ipv6 = var.server_ipv6

    providers = {
      cloudflare = cloudflare
    }
  }
  ```

- [ ] **Step 5: Add zone-id output at root**

Use Edit on `terraform/outputs.tf`:
- old_string:
  ```
  output "eic_seminarios_zone_id" {
    description = "Cloudflare zone ID for eic-seminarios.com."
    value       = module.eic_seminarios.eic_seminarios_zone_id
  }
  ```
- new_string:
  ```
  output "eic_seminarios_zone_id" {
    description = "Cloudflare zone ID for eic-seminarios.com."
    value       = module.eic_seminarios.eic_seminarios_zone_id
  }

  output "joy_living_zone_id" {
    description = "Cloudflare zone ID for joyliving.com.br."
    value       = module.joy_living.joy_living_zone_id
  }
  ```

- [ ] **Step 6: Verify**

Run: `cd /Users/j/src/jorgejr568/aws-resources/terraform && terraform fmt -check -recursive`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add terraform/projects/joy-living/ terraform/main.tf terraform/outputs.tf
git commit -m "feat(tf): add joy-living project (joyliving.com.br)"
```

---

### Task 9: Wire `CLOUDFLARE_API_TOKEN` and `TF_VAR_*` into the workflows

**Files:**
- Modify: `.github/workflows/terraform-plan.yml`
- Modify: `.github/workflows/terraform-apply.yml`

Both workflows currently only set AWS credentials. Cloudflare provider needs `CLOUDFLARE_API_TOKEN`; the three new variables need `TF_VAR_*` env. Setting them as job-level env keeps them on every step that runs Terraform.

- [ ] **Step 1: Edit `terraform-plan.yml` to add a job-level `env:` block**

Use Edit on `.github/workflows/terraform-plan.yml`:
- old_string:
  ```
  jobs:
    plan:
      name: plan
      runs-on: ubuntu-latest
      concurrency:
        group: terraform-plan-${{ github.ref }}
        cancel-in-progress: true
      defaults:
        run:
          working-directory: terraform
      steps:
  ```
- new_string:
  ```
  jobs:
    plan:
      name: plan
      runs-on: ubuntu-latest
      concurrency:
        group: terraform-plan-${{ github.ref }}
        cancel-in-progress: true
      defaults:
        run:
          working-directory: terraform
      env:
        CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        TF_VAR_server_ipv4: ${{ vars.SERVER_IPV4 }}
        TF_VAR_server_ipv6: ${{ vars.SERVER_IPV6 }}
        TF_VAR_cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
      steps:
  ```

- [ ] **Step 2: Edit `terraform-apply.yml` the same way**

Use Edit on `.github/workflows/terraform-apply.yml`:
- old_string:
  ```
  jobs:
    apply:
      name: apply
      runs-on: ubuntu-latest
      concurrency:
        group: terraform-apply
        cancel-in-progress: false
      defaults:
        run:
          working-directory: terraform
      steps:
  ```
- new_string:
  ```
  jobs:
    apply:
      name: apply
      runs-on: ubuntu-latest
      concurrency:
        group: terraform-apply
        cancel-in-progress: false
      defaults:
        run:
          working-directory: terraform
      env:
        CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        TF_VAR_server_ipv4: ${{ vars.SERVER_IPV4 }}
        TF_VAR_server_ipv6: ${{ vars.SERVER_IPV6 }}
        TF_VAR_cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
      steps:
  ```

- [ ] **Step 3: Verify YAML parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('/Users/j/src/jorgejr568/aws-resources/.github/workflows/terraform-plan.yml')); yaml.safe_load(open('/Users/j/src/jorgejr568/aws-resources/.github/workflows/terraform-apply.yml')); print('OK')"`
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add .github/workflows/terraform-plan.yml .github/workflows/terraform-apply.yml
git commit -m "ci: pass cloudflare token + server IPs + account id to terraform"
```

---

### Task 10: Local validation pass

**Files:** none modified.

These checks confirm the new code is internally consistent before we ask CI to apply it. They do not require AWS or Cloudflare credentials.

- [ ] **Step 1: Confirm clean tree**

Run: `git -C /Users/j/src/jorgejr568/aws-resources status`
Expected: `nothing to commit, working tree clean`.

- [ ] **Step 2: `terraform fmt -check`**

Run: `cd /Users/j/src/jorgejr568/aws-resources/terraform && terraform fmt -check -recursive`
Expected: exit 0.

- [ ] **Step 3: Project layout sanity check**

Run: `ls /Users/j/src/jorgejr568/aws-resources/terraform/projects/`
Expected (alphabetical):
```
eic-seminarios
hooks-fyi
jorgejunior
joy-living
rentivo
```

There is **no** `vista-da-montanha/` directory — that domain is no longer owned and was deliberately not ported.

- [ ] **Step 4: Each project has `versions.tf`, and CF projects have `cloudflare.tf` + `variables.tf`**

Run:
```bash
for d in /Users/j/src/jorgejr568/aws-resources/terraform/projects/*/; do
  echo "== $d =="
  ls "$d"
done
```
Expected:
- `eic-seminarios/`: cloudflare.tf, variables.tf, versions.tf
- `hooks-fyi/`: cloudflare.tf, iam.tf, s3.tf, variables.tf, versions.tf
- `jorgejunior/`: cloudflare.tf, variables.tf, versions.tf
- `joy-living/`: cloudflare.tf, variables.tf, versions.tf
- `rentivo/`: cloudflare.tf, iam.tf, s3.tf, ses.tf, variables.tf, versions.tf

- [ ] **Step 5: `terraform validate` (skips backend init via `-backend=false`)**

Run:
```bash
cd /Users/j/src/jorgejr568/aws-resources/terraform
terraform init -backend=false -input=false
terraform validate
```
Expected: `Success! The configuration is valid.` If validation reports any error, the implementer must fix it before continuing — common causes are typos in module-block argument names or missing variables in a project.

- [ ] **Step 6: Spot-check that every Pulumi record file has a corresponding Terraform resource**

This is the audit that catches silently-dropped records. For each Pulumi source file, count records and compare.

Run: `grep -rE 'createAddressRecordsToServer|createCnameRecord|createMxRecord|createTxtRecord|createVercelCname' /Users/j/src/jorgejr568/aws-resources/cloudflare-resources/records/ | wc -l`
Note this number — it's a rough count of Pulumi record-creation call sites (each `createAddressRecordsToServer` produces 2 records (A+AAAA), each other helper produces 1).

Run: `grep -rE 'resource "cloudflare_record"' /Users/j/src/jorgejr568/aws-resources/terraform/projects/ | wc -l`
This counts Terraform `cloudflare_record` blocks. Each block with `for_each` expands per element.

These counts will not match exactly (loops vs. literal), so the validation here is by-zone manual review:
- `hooks-fyi-records.go`: 2 subdomains × A+AAAA = 4 records → Terraform: `hooks_fyi_a` (2) + `hooks_fyi_aaaa` (2) = 4 ✓
- `rentivo-com-br-records.go`: 2×2 + 1 TXT + 3 CNAME + 1 MX + 1 TXT = 10 → Terraform: `rentivo_a` (2) + `rentivo_aaaa` (2) + `rentivo_dmarc` (1) + `rentivo_ses_dkim` (3, dynamic) + `rentivo_mail_mx` (1) + `rentivo_mail_spf` (1) = 10 ✓
- `jorge-junior-dev-records.go`: 16×2 + 3 MX = 35 → Terraform: `jorgejunior_dev_a` (16) + `jorgejunior_dev_aaaa` (16) + `jorgejunior_dev_mx` (3) = 35 ✓
- `j-jr-app-records.go`: 8×2 + 2 CNAME = 18 → Terraform: `j_jr_app_a` (8) + `j_jr_app_aaaa` (8) + `j_jr_app_vercel` (2) = 18 ✓
- `eic-seminarios-records.go`: 1×2 = 2 → Terraform: `eic_seminarios_a` (1) + `eic_seminarios_aaaa` (1) = 2 ✓
- `vista-da-montanha-com-br-records.go`: **NOT PORTED** (3 records) — domain no longer owned. Confirm there is no `vista_da_montanha` resource anywhere: `grep -r vista_da_montanha /Users/j/src/jorgejr568/aws-resources/terraform/` should return no results.
- `joy-living-records.go`: 3×2 = 6 → Terraform: `joy_living_a` (3) + `joy_living_aaaa` (3) = 6 ✓

**Grand total: 75 records.** If `terraform plan` (run by CI on the cutover PR) reports a different create count, something was missed.

- [ ] **Step 7: No commit — this task only validates.**

---

### Task 11: Document the manual cutover steps in the PR description

**Files:** none modified directly. This task produces the *PR body* the implementer (or human) will use when opening the cutover PR. Save it as a scratch file at `docs/superpowers/plans/2026-04-30-cutover-runbook.md` so future sessions can find it.

- [ ] **Step 1: Write the runbook**

Use Write to create `docs/superpowers/plans/2026-04-30-cutover-runbook.md`:

```markdown
# Cutover runbook: Pulumi → Terraform for Cloudflare DNS

This runbook covers the *manual* steps that bracket the PR. The PR itself is purely code; the cutover is what makes it live.

## Pre-merge — set GitHub repo variables (once)

Required because the new Terraform vars are sourced from `vars.*`:

```bash
# from inside the cloudflare-resources/ directory, while it still has Pulumi config:
SERVER_IPV4=$(pulumi config get server:ipv4 --stack production --show-secrets)
SERVER_IPV6=$(pulumi config get server:ipv6 --stack production --show-secrets)
CF_ACCOUNT_ID=$(pulumi config get cf:accountId --stack production --show-secrets)

gh variable set SERVER_IPV4 -b "$SERVER_IPV4" -R jorgejr568/aws-resources
gh variable set SERVER_IPV6 -b "$SERVER_IPV6" -R jorgejr568/aws-resources
gh variable set CLOUDFLARE_ACCOUNT_ID -b "$CF_ACCOUNT_ID" -R jorgejr568/aws-resources
```

Verify: `gh variable list -R jorgejr568/aws-resources` should now include `SERVER_IPV4`, `SERVER_IPV6`, `CLOUDFLARE_ACCOUNT_ID`.

## Pre-merge — set GitHub repo secret (once)

```bash
# Reuse the same token the Pulumi side used. If you don't have it locally,
# regenerate at https://dash.cloudflare.com/profile/api-tokens and rotate.
gh secret set CLOUDFLARE_API_TOKEN -R jorgejr568/aws-resources
```

## Pre-merge — confirm `terraform-plan` PR comment shows ~75 creates and 0 destroys

If the count is different, STOP and reconcile with the audit in Task 10 Step 6 before continuing.

## At merge time — destroy the Pulumi stack first

This is the brief-downtime moment:

```bash
cd cloudflare-resources
pulumi stack select production
pulumi destroy --stack production --yes
```

Pulumi will tear down all Cloudflare records it manages, including the 3 obsolete `vistadamontanha.com.br` records (the lookup of that zone may fail if the zone is gone — Pulumi will report an error during destroy; if so, manually remove those resources from Pulumi state with `pulumi state delete <urn>` for each `vista-da-montanha-*` URN, then re-run destroy).

## At merge time — merge the PR

Once `pulumi destroy` reports success, merge the PR. The `terraform-apply` workflow will run `terraform apply` and recreate the 75 records the new Terraform owns. (vista-da-montanha is intentionally not in the new set.)

## Post-merge — verify

- Visit the Cloudflare dashboard for each zone, confirm record count.
- For proxied zones: `dig +short A hooks.fyi` should resolve to a Cloudflare proxy IP (e.g. starts with `104.` or `172.`), not the origin.
- `terraform output -raw hooks_fyi_zone_id` etc. should return the same zone IDs Pulumi used to export.

## Post-merge — clean up Pulumi side

After confirming the new records work:

```bash
# Delete the (now-empty) Pulumi stack
cd cloudflare-resources
pulumi stack rm production --yes

# Archive the old GitHub repo (does NOT delete it)
gh repo archive jorgejr568/cloudflare-resources

# Optional: rename this repo
gh repo rename infra-resources -R jorgejr568/aws-resources
git -C /Users/j/src/jorgejr568/aws-resources remote set-url origin git@github.com:jorgejr568/infra-resources.git
```

## Rollback plan

If `terraform apply` fails partway through:
1. The Cloudflare records that did get created are now in Terraform state — leave them.
2. Fix the failing config in a follow-up commit, push, let `terraform-apply` run again.
3. If you need to roll *all the way* back to Pulumi: `cd cloudflare-resources && pulumi up --stack production` would re-create them, but only if the Pulumi tree is still in this repo (i.e. the cutover PR hasn't deleted it yet — see Task 13). Once Task 13 lands, rollback means restoring `cloudflare-resources/` from the pre-deletion commit and `pulumi up`.
```

- [ ] **Step 2: Commit the runbook**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add docs/superpowers/plans/2026-04-30-cutover-runbook.md
git commit -m "docs: add cutover runbook for pulumi -> terraform migration"
```

---

### Task 12: Update README and ARCHITECTURE.md

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Rewrite README**

Use Write to overwrite `/Users/j/src/jorgejr568/aws-resources/README.md`:

```markdown
# infra-resources

Terraform-managed infrastructure for the `jorgejr568` ecosystem (AWS + Cloudflare DNS), applied via GitHub Actions.

> Repo is currently named `aws-resources` on GitHub; rename to `infra-resources` is a separate manual step (see [`docs/superpowers/plans/2026-04-30-cutover-runbook.md`](docs/superpowers/plans/2026-04-30-cutover-runbook.md)).

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
   - `CLOUDFLARE_ACCOUNT_ID`
4. **Push to `main`** — the apply workflow runs automatically.
5. **For changes thereafter**, open a PR. The plan workflow comments the diff. Merge to apply.

## Layout

- `terraform/projects/<project>/` — one Terraform child module per project. Each project owns its AWS *and* its Cloudflare resources. Projects: `eic-seminarios`, `hooks-fyi`, `jorgejunior` (jorgejunior.dev + j-jr.app), `joy-living`, `rentivo`.
- `terraform/` — root module: `main.tf`, `providers.tf`, `versions.tf`, `backend.tf`, `outputs.tf`, `variables.tf`. One state for everything.
- `.github/workflows/` — `terraform-plan.yml` (PR), `terraform-apply.yml` (main).
- `scripts/` — operational scripts (state backend bootstrap).
- `docs/` — architecture and decision docs, plus implementation plans under `docs/superpowers/plans/`.
```

- [ ] **Step 2: Update ARCHITECTURE.md intro**

Use Edit on `docs/ARCHITECTURE.md`:
- old_string:
  ```
  # Architecture

  ## Purpose

  `aws-resources` is the single source of truth for AWS infrastructure managed under the `jorgejr568` account, applied through CI/CD. Every change to AWS state goes through a PR, a `terraform plan`, a review, and a `terraform apply` triggered by merging to `main`.
  ```
- new_string:
  ```
  # Architecture

  ## Purpose

  This repo is the single source of truth for the infrastructure managed under the `jorgejr568` account — AWS resources and Cloudflare DNS — applied through CI/CD. Every change goes through a PR, a `terraform plan`, a review, and a `terraform apply` triggered by merging to `main`. AWS and Cloudflare share one root module and one state file; per-project child modules group resources by application/domain.
  ```

- [ ] **Step 3: Update the layout section to mention CF**

Use Edit on `docs/ARCHITECTURE.md`:
- old_string:
  ```
  | File | Responsibility |
  |------|----------------|
  | `s3.tf`        | All S3 buckets and their hardening (encryption, public-access-block, versioning, ownership) |
  | `iam.tf`       | All IAM users, policies, attachments, access keys |
  | `outputs.tf`   | Outputs the root module needs to re-export |
  | `variables.tf` | (optional) inputs the root passes in |
  ```
- new_string:
  ```
  | File | Responsibility |
  |------|----------------|
  | `s3.tf`         | All S3 buckets and their hardening (encryption, public-access-block, versioning, ownership) |
  | `iam.tf`        | All IAM users, policies, attachments, access keys |
  | `ses.tf`        | SES domain identity + DKIM, if the project sends email |
  | `cloudflare.tf` | Cloudflare zone lookups + DNS records for the project's zone(s) |
  | `variables.tf`  | (optional) inputs the root passes in (e.g. `server_ipv4`, `server_ipv6`) |
  | `outputs.tf`    | Outputs the root module re-exports (some projects co-locate outputs in their resource files) |

  **Cloudflare DNS belongs to the project that owns the zone.** A project can be CF-only (e.g. `joy-living` has no AWS), AWS-only, or both (e.g. `rentivo` has SES + S3 + CF, with CF DKIM CNAMEs wired directly to `aws_ses_domain_dkim.rentivo.dkim_tokens` so there are no hardcoded tokens).
  ```

- [ ] **Step 4: Update the "Current projects" section to mention all six**

Use Edit on `docs/ARCHITECTURE.md`:
- old_string:
  ```
  ## Current projects

  ### `hooks-fyi`

  Owns:
  - `hooks-fyi-request-files` S3 bucket (versioned, AES256-encrypted, all public access blocked).
  - `hooks-fyi` IAM user with read-write access scoped to the above bucket.
  - An access key for `hooks-fyi`, exposed via sensitive Terraform outputs.
  ```
- new_string:
  ```
  ## Current projects

  ### `hooks-fyi`
  - AWS: `hooks-fyi-request-files` S3 bucket (versioned, AES256-encrypted, all public access blocked); `hooks-fyi` IAM user with read-write access to the bucket; access key surfaced via sensitive outputs.
  - Cloudflare: `hooks.fyi` zone — `@`, `www` proxied A/AAAA.

  ### `rentivo`
  - AWS: S3 bucket `rentivo-files`, IAM user, SES domain identity + DKIM.
  - Cloudflare: `rentivo.com.br` zone — `@`/`www` proxied A/AAAA, DMARC TXT, three SES DKIM CNAMEs (sourced from `aws_ses_domain_dkim` output), `mail` MX + SPF TXT.

  ### `jorgejunior`
  - Cloudflare only: `jorgejunior.dev` (16 proxied subdomains + SES bounce MX + Mailgun MX) and `j-jr.app` (8 proxied subdomains + 2 Vercel CNAMEs).

  ### `eic-seminarios`
  - Cloudflare only: `eic-seminarios.com` zone — `v2` proxied A/AAAA.

  ### `joy-living`
  - Cloudflare only: `joyliving.com.br` zone — `@`, `www`, `api` proxied A/AAAA.
  ```

- [ ] **Step 5: Add Cloudflare auth section right after the Authentication section**

Use Edit on `docs/ARCHITECTURE.md`:
- old_string:
  ```
  > **Future work:** Replace the CI access keys with GitHub OIDC + an IAM role (`role-to-assume`). This eliminates long-lived secrets.
  ```
- new_string:
  ```
  > **Future work:** Replace the CI access keys with GitHub OIDC + an IAM role (`role-to-assume`). This eliminates long-lived secrets.

  ### Cloudflare authentication
  | Secret / Var | Purpose |
  |--------------|---------|
  | `CLOUDFLARE_API_TOKEN` (secret) | Cloudflare API token consumed by the cloudflare provider |
  | `SERVER_IPV4` (var)             | Origin IPv4 used by all proxied A records |
  | `SERVER_IPV6` (var)             | Origin IPv6 used by all proxied AAAA records |
  | `CLOUDFLARE_ACCOUNT_ID` (var)   | Cloudflare account ID (currently passthrough output only) |

  These are surfaced to Terraform via `TF_VAR_*` env in the workflows. The values are not sensitive (server IPs are published in DNS; the account ID is non-secret) but live outside the repo to avoid hardcoding environment-specific values.
  ```

- [ ] **Step 6: Verify**

Use the Read tool on `docs/ARCHITECTURE.md` (first 100 lines).
Expected: updated Purpose, expanded `cloudflare.tf` row, six projects listed.

- [ ] **Step 7: Commit**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add README.md docs/ARCHITECTURE.md
git commit -m "docs: rewrite README and ARCHITECTURE for combined AWS + Cloudflare repo"
```

---

### Task 13: Delete the `cloudflare-resources/` Pulumi tree

This is the *last* code task. Doing it earlier would lose the spec we're porting from. Doing it later means the runbook in Task 11 references rollback paths that already work.

**Files:**
- Delete: entire `cloudflare-resources/` directory.

- [ ] **Step 1: Confirm we're caught up**

Run: `git -C /Users/j/src/jorgejr568/aws-resources status --short`
Expected: clean.

Run: `git -C /Users/j/src/jorgejr568/aws-resources log --oneline -15`
Expected: 11 fresh commits from Tasks 1–12 above (one per task, except Task 10 which is verify-only).

- [ ] **Step 2: Remove the directory**

Run: `rm -rf /Users/j/src/jorgejr568/aws-resources/cloudflare-resources`
Expected: exit 0.

- [ ] **Step 3: Verify**

Run: `test -d /Users/j/src/jorgejr568/aws-resources/cloudflare-resources && echo "STILL THERE" || echo "gone"`
Expected: `gone`.

Run: `git -C /Users/j/src/jorgejr568/aws-resources status --short | head -20`
Expected: many lines starting with ` D cloudflare-resources/...` (deleted, staged for removal once `git add -u` runs).

- [ ] **Step 4: Commit the deletion**

```bash
cd /Users/j/src/jorgejr568/aws-resources
git add -u cloudflare-resources/
git rm -r --cached cloudflare-resources/ 2>/dev/null || true
git status --short
git commit -m "chore: remove cloudflare-resources/ (ported to terraform)"
```

(The `git rm --cached` is defensive — `git add -u` should already mark the deletions, but if any file was somehow still tracked, this catches it.)

Run: `git status`
Expected: clean tree.

- [ ] **Step 5: Final layout check**

Run: `ls /Users/j/src/jorgejr568/aws-resources/`
Expected: `.github/  .gitignore  .tool-versions  README.md  docs/  scripts/  terraform/` — no `cloudflare-resources/`.

---

## Out-of-plan manual steps (executed by the human)

These bracket the PR. The plan above produces the PR; these are the cutover.

1. **Set GitHub vars and the CF secret** (see `docs/superpowers/plans/2026-04-30-cutover-runbook.md`, produced by Task 11). Do this *before* opening the PR so the `terraform-plan` workflow has the values.

2. **Open the PR.** Confirm the plan comment shows ~75 records to create and 0 to destroy. If counts differ, audit against Task 10 Step 6.

3. **Just before merge:** `pulumi destroy --stack production` from a workspace that still has the Pulumi tree (e.g. a checkout of the *old* `cloudflare-resources` GitHub repo, since Task 13 deletes the tree from this repo).

4. **Merge the PR** — `terraform-apply` recreates the records.

5. **Verify** in the Cloudflare dashboard and via `dig`.

6. **Clean up** — `pulumi stack rm`, `gh repo archive jorgejr568/cloudflare-resources`, optional `gh repo rename infra-resources`.

---

## Self-review checks (informational, already applied during plan authoring)

- ✅ Spec coverage — every record file in `cloudflare-resources/records/` maps to a Terraform resource block, **except** `vista-da-montanha-com-br-records.go` which is intentionally dropped (domain no longer owned). Task 10 Step 6 enumerates the 6 ported zones × records totalling 75.
- ✅ No placeholders — every step contains literal HCL/YAML/shell. The single `<INNER_HEAD_SHA>` token in Task 1 is a captured-value handoff between Steps 2 and 5, not an unfilled placeholder.
- ✅ Type/identifier consistency — output names (`*_zone_id`), local names (`*_proxied_subdomains`), and module names (`hooks_fyi`, `jorgejunior`, etc.) are consistent across the root and project tasks.
- ✅ Greenfield migration explicitly chosen — no `terraform import` steps; downtime acceptance documented in the runbook.
