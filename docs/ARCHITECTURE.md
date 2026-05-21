# Architecture

## Purpose

This repo is the single source of truth for the infrastructure managed under the `jorgejr568` account — AWS resources and Cloudflare DNS — applied through CI/CD. Every change goes through a PR, a `terraform plan`, a review, and a `terraform apply` triggered by merging to `main`. AWS and Cloudflare share one root module and one state file; per-project child modules group resources by application/domain.

## Repository layout

```
.
├── .github/workflows/             # CI/CD entrypoints
├── terraform/                     # the one Terraform root module
│   ├── versions.tf                # required terraform / providers
│   ├── providers.tf               # AWS provider config + default tags
│   ├── backend.tf                 # remote state (S3 + native lockfile)
│   ├── variables.tf               # root inputs
│   ├── outputs.tf                 # surfaces module outputs to the root
│   ├── main.tf                    # `module "<project>" { source = "./projects/<project>" }`
│   ├── .tflint.hcl                # tflint config (terraform + aws rulesets)
│   ├── modules/                   # shared primitive modules (small, reusable)
│   │   └── cloudflare-default-server-subdomains/
│   └── projects/
│       └── <project>/             # one child module per application/project
│           ├── s3.tf              # bucket(s) for this project
│           ├── iam.tf             # user(s) and policies for this project
│           └── outputs.tf         # outputs the root module re-exports
├── scripts/                       # one-off operational scripts
├── docs/                          # design + decision records
├── .pre-commit-config.yaml        # local fmt/validate/tflint hooks
├── .trivyignore                   # trivy config-scan suppressions (with rationale)
├── .tool-versions                 # tfenv / asdf hint (terraform version)
└── README.md                      # quick-start for humans
```

### One root module, many project sub-modules

There is **one** Terraform root module, at `terraform/`, with **one** state file. Inside it, resources are grouped per application under `terraform/projects/<project>/` purely as a way to keep files organized — each project is a Terraform child module, not its own root module. They share the root's provider, backend, and state.

Why this shape:
- **One state, one apply.** A change in one project gets planned and applied in the same run as everything else. No risk of drift between separately-applied projects.
- **File-level context.** Browsing `terraform/projects/hooks-fyi/` shows everything that belongs to the `hooks-fyi` app and nothing else.
- **Simple CI.** The workflows run a single `terraform init/plan/apply` against `terraform/`. Adding a project is a folder + a `module` block in `main.tf` — no CI changes.

Trade-off: blast radius is larger (one bad apply affects everything in this repo). For our scale that's acceptable; if it becomes a concern later we'd promote a project into its own root module with its own state.

### Shared primitive modules

`terraform/modules/` holds small reusable building blocks distinct from per-project child modules under `terraform/projects/`. They're primitives — equivalent in role to `aws_s3_bucket_versioning` or `aws_s3_bucket_public_access_block` — not project boundaries.

Currently the only one is `cloudflare-default-server-subdomains`: given a Cloudflare zone, a set of subdomains, and an IPv4/IPv6 pair, it emits the A and AAAA records pointing at the default origin server. A `proxied` boolean (default `true`) toggles Cloudflare proxying so the same primitive serves both proxied callers and DNS-only ones (the `eic-seminarios` `s3-beta` records, where SigV4 needs an unproxied DNS path). MX, DKIM, TXT, and Vercel CNAMEs remain inline in each project — they don't share the same shape.

### Adding a project

1. Create `terraform/projects/<new-project>/` with `s3.tf`, `iam.tf`, `outputs.tf`, etc. No `backend.tf`, no `providers.tf` — the root module supplies those.
2. Add to `terraform/main.tf`:
   ```hcl
   module "<new_project>" {
     source = "./projects/<new-project>"
   }
   ```
3. Re-export anything you need at the root by adding to `terraform/outputs.tf`.

### Files inside a project

| File | Responsibility |
|------|----------------|
| `s3.tf`         | All S3 buckets and their hardening (encryption, public-access-block, versioning, ownership) |
| `iam.tf`        | All IAM users, policies, attachments, access keys |
| `ses.tf`        | SES domain identity + DKIM, if the project sends email |
| `cloudflare.tf` | Cloudflare zone lookups + DNS records for the project's zone(s) |
| `variables.tf`  | (optional) inputs the root passes in (e.g. `server_ipv4`, `server_ipv6`) |
| `outputs.tf`    | Outputs the root module re-exports (some projects co-locate outputs in their resource files) |

**Cloudflare DNS belongs to the project that owns the zone.** A project can be CF-only (e.g. `joy-living` has no AWS), AWS-only, or both (e.g. `rentivo` has SES + S3 + CF, with CF DKIM CNAMEs wired directly to `aws_ses_domain_dkim.rentivo.dkim_tokens` so there are no hardcoded tokens).

Within a project, resources are grouped by AWS service, not by feature.

## Current projects

### `hooks-fyi`
- AWS: `hooks-fyi-request-files` S3 bucket (versioned, AES256-encrypted, all public access blocked); `hooks-fyi` IAM user with read-write access to the bucket; access key surfaced via sensitive outputs.
- Cloudflare: `hooks.fyi` zone — `@`, `www` proxied A/AAAA.

### `rentivo`
- AWS: S3 bucket `rentivo-files`, IAM user, SES domain identity + DKIM.
- Cloudflare: `rentivo.com.br` zone — `@`/`www` proxied A/AAAA, DMARC TXT, three SES DKIM CNAMEs (sourced from `aws_ses_domain_dkim` output), `mail` MX + SPF TXT.

### `jorgejunior`
- Cloudflare only: `jorgejunior.dev` (16 proxied subdomains + SES bounce MX + Mailgun MX) and `j-jr.app` (8 proxied subdomains + 2 Vercel CNAMEs). Also owns the `jorgejunior.dev portfolio` Turnstile widget (account-scoped, managed mode, allowed on `jorgejunior.dev` + `www.jorgejunior.dev` + `me.jorgejunior.dev`); sitekey/secret are surfaced as root outputs (`jorgejunior_portfolio_turnstile_sitekey`, `jorgejunior_portfolio_turnstile_secret`).

### `eic-seminarios`
- Cloudflare only: `eic-seminarios.com` zone — `v2` proxied A/AAAA.

### `joy-living`
- Cloudflare only: `joyliving.com.br` zone — `@`, `www`, `api` proxied A/AAAA.

## State management

State is stored remotely in:
- **Bucket:** `jorgejr568-aws-resources-tfstate` (versioned, AES256-encrypted, public access blocked).
- **Locking:** S3-native via `use_lockfile = true` (Terraform ≥ 1.10) — a sibling `.tflock` object next to the state key. No DynamoDB table.
- **Region:** `us-east-1`.
- **Key:** `aws-resources.tfstate`.

The state bucket is created once via `scripts/bootstrap-backend.sh`. The script is idempotent so re-running is safe.

> ⚠ State contains sensitive values (notably IAM access key secrets). Read access to `jorgejr568-aws-resources-tfstate` should be restricted to the same humans/automation that can apply this repo.

## Authentication

GitHub Actions authenticates to AWS using long-lived access keys for an IAM user with administrative-equivalent permissions on the resources we manage, stored as repo secrets:

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID`     | CI access key id |
| `AWS_SECRET_ACCESS_KEY` | CI secret |

The CI user is **not** the same as any project's service account (e.g. `hooks-fyi`). Project users are managed by Terraform with narrowly-scoped permissions; the CI user is broader and is created out-of-band.

> **Future work:** Replace the CI access keys with GitHub OIDC + an IAM role (`role-to-assume`). This eliminates long-lived secrets.

### Cloudflare authentication
| Secret / Var | Purpose |
|--------------|---------|
| `CLOUDFLARE_API_TOKEN` (secret)    | Cloudflare API token consumed by the cloudflare provider |
| `SERVER_IPV4` (var)                | Origin IPv4 used by all proxied A records |
| `SERVER_IPV6` (var)                | Origin IPv6 used by all proxied AAAA records |
| `CLOUDFLARE_ACCOUNT_ID` (var)      | Cloudflare account ID used by account-scoped resources (Turnstile) |

These are surfaced to Terraform via `TF_VAR_*` env in the workflows. The values are not sensitive (server IPs are published in DNS) but live outside the repo to avoid hardcoding environment-specific values.

## CI/CD flows

Both workflows run in the `terraform/` directory. Because there is one root module, one `init/plan/apply` covers every project.

### Plan (on PR)

Trigger: `pull_request` targeting `main`, when `terraform/**` or workflow files change.

Three jobs run in parallel under `pr-checks.yml`:

1. **terraform-plan** — `fmt -check`, `init`, `validate`, `plan -out=tfplan`, then posts the plan as a PR comment.
2. **tflint** — runs `tflint --recursive` against `terraform/` with the `terraform` (recommended preset) and `aws` rulesets. Config lives at `terraform/.tflint.hcl`.
3. **trivy-config** — `aquasecurity/trivy-action` running `trivy config --severity HIGH,CRITICAL terraform/`. Suppressions live in `.trivyignore` with one-line rationale per entry.

A final `plan` aggregator job requires all three to be `success` or `skipped` (the paths-filter skips them when only docs change).

### Apply (on merge / manual)
Triggers:
- `push` to `main` when `terraform/**` or workflow files change.
- `workflow_dispatch` (manual run from the Actions tab).
1. Checkout
2. Configure AWS credentials
3. `terraform fmt -check -recursive` (no `continue-on-error` — manual runs can't bypass fmt)
4. `terraform init`
5. `terraform validate`
6. `terraform plan -no-color -out=tfplan`
7. `terraform apply -auto-approve tfplan`

A single `concurrency: terraform-apply` group prevents two simultaneous applies from racing the state lock.

### Local checks

`pre-commit` (`.pre-commit-config.yaml`) wires up the same `terraform_fmt`, `terraform_validate`, and `terraform_tflint` hooks for local commits. Optional but recommended — CI is the source of truth.

## Bootstrap order (one-time, per AWS account)

1. Create the CI IAM user (admin-ish) **outside** this repo and capture its keys.
2. Run `./scripts/bootstrap-backend.sh` from a machine logged in to that account.
3. Add `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` as GitHub repo secrets.
4. Push to `main` (or rerun the apply workflow). CI takes over from here.

## Adding a new resource

1. Branch off `main`.
2. Decide which project it belongs to (or create a new project — see "Adding a project" above).
3. Add or extend the appropriate `<service>.tf` under `terraform/projects/<project>/`.
4. Open a PR. The plan workflow comments the diff.
5. Get review, merge. The apply workflow rolls it out.

## Reading sensitive outputs

```bash
cd terraform
terraform init
terraform output -raw <output_name>
```
Requires read access to the state bucket. Don't commit, don't paste in chat.
