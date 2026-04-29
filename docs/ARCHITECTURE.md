# Architecture

## Purpose

`aws-resources` is the single source of truth for AWS infrastructure managed under the `jorgejr568` account, applied through CI/CD. Every change to AWS state goes through a PR, a `terraform plan`, a review, and a `terraform apply` triggered by merging to `main`.

## Repository layout

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
│   └── projects/
│       └── <project>/             # one child module per application/project
│           ├── s3.tf              # bucket(s) for this project
│           ├── iam.tf             # user(s) and policies for this project
│           └── outputs.tf         # outputs the root module re-exports
├── scripts/                       # one-off operational scripts
├── docs/                          # design + decision records
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
| `s3.tf`        | All S3 buckets and their hardening (encryption, public-access-block, versioning, ownership) |
| `iam.tf`       | All IAM users, policies, attachments, access keys |
| `outputs.tf`   | Outputs the root module needs to re-export |
| `variables.tf` | (optional) inputs the root passes in |

Within a project, resources are grouped by AWS service, not by feature.

## Current projects

### `hooks-fyi`

Owns:
- `hooks-fyi-request-files` S3 bucket (versioned, AES256-encrypted, all public access blocked).
- `hooks-fyi` IAM user with read-write access scoped to the above bucket.
- An access key for `hooks-fyi`, exposed via sensitive Terraform outputs.

## State management

State is stored remotely in:
- **Bucket:** `jorgejr568-aws-resources-tfstate` (versioned, AES256-encrypted, public access blocked).
- **Lock table:** `aws-resources-tflock` (DynamoDB, on-demand billing).
- **Region:** `us-east-1`.
- **Key:** `aws-resources.tfstate`.

Both backend resources are created once via `scripts/bootstrap-backend.sh`. The script is idempotent so re-running is safe.

> ⚠ State contains sensitive values (notably IAM access key secrets). Read access to `jorgejr568-aws-resources-tfstate` should be restricted to the same humans/automation that can apply this repo.

## Authentication

GitHub Actions authenticates to AWS using long-lived access keys for an IAM user with administrative-equivalent permissions on the resources we manage, stored as repo secrets:

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID`     | CI access key id |
| `AWS_SECRET_ACCESS_KEY` | CI secret |

The CI user is **not** the same as any project's service account (e.g. `hooks-fyi`). Project users are managed by Terraform with narrowly-scoped permissions; the CI user is broader and is created out-of-band.

> **Future work:** Replace the CI access keys with GitHub OIDC + an IAM role (`role-to-assume`). This eliminates long-lived secrets.

## CI/CD flows

Both workflows run in the `terraform/` directory. Because there is one root module, one `init/plan/apply` covers every project.

### Plan (on PR)
Trigger: `pull_request` targeting `main`, when `terraform/**` or workflow files change.
1. Checkout
2. Configure AWS credentials
3. `terraform fmt -check -recursive`
4. `terraform init`
5. `terraform validate`
6. `terraform plan -no-color -out=tfplan`
7. Post the plan as a PR comment

### Apply (on merge / manual)
Triggers:
- `push` to `main` when `terraform/**` or workflow files change.
- `workflow_dispatch` (manual run from the Actions tab).
1. Checkout
2. Configure AWS credentials
3. `terraform init`
4. `terraform validate`
5. `terraform plan -no-color -out=tfplan`
6. `terraform apply -auto-approve tfplan`

A single `concurrency: terraform-apply` group prevents two simultaneous applies from racing the state lock.

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
