# Architecture

## Purpose

`aws-resources` is the single source of truth for AWS infrastructure managed under the `jorgejr568` account, applied through CI/CD. Every change to AWS state goes through a PR, a `terraform plan`, a review, and a `terraform apply` triggered by merging to `main`.

## Repository layout

```
.
├── .github/workflows/             # CI/CD entrypoints
├── terraform/
│   └── projects/
│       └── <project>/             # one Terraform root module per project
├── scripts/                       # one-off operational scripts
├── docs/                          # design + decision records
├── .tool-versions                 # tfenv / asdf hint (terraform version)
└── README.md                      # quick-start for humans
```

### One root module per project

Resources are organized by **project** under `terraform/projects/<project>/`. Each project is its own Terraform root module with:
- Its own state file (key: `projects/<project>/terraform.tfstate` in the shared state bucket).
- Its own provider config and variables.
- Its own apply lifecycle — projects can be planned and applied independently.

Why split this way:
- **Blast radius:** a broken plan in one project never blocks another.
- **State size:** state stays small and operations stay fast.
- **Ownership:** when teams or contexts diverge, projects can be moved or restricted independently.

Adding a new project = create `terraform/projects/<new-project>/` with its own `versions.tf`, `providers.tf`, `backend.tf` (with a unique state key), `variables.tf`, and resource files. Then add the project name to the matrix in both workflows (see CI section).

### Files inside a project

| File | Responsibility |
|------|----------------|
| `versions.tf`  | Terraform + provider version constraints |
| `providers.tf` | `aws` provider config + default tags |
| `backend.tf`   | S3 + DynamoDB remote state (project-specific key) |
| `variables.tf` | Input variables (region, etc.) |
| `outputs.tf`   | Cross-cutting outputs (most outputs live next to their resource) |
| `s3.tf`        | All S3 buckets and their hardening (encryption, public-access-block, versioning, ownership) |
| `iam.tf`       | All IAM users, policies, attachments, access keys |

Within a project, resources are grouped by AWS service, not by feature. When a feature spans services (e.g. "request files" = bucket + user + policy), the pieces live in their service-appropriate file and are wired through Terraform references.

## Current projects

### `hooks-fyi`

Owns:
- `hooks-fyi-request-files` S3 bucket (versioned, AES256-encrypted, all public access blocked).
- `hooks-fyi` IAM user with read-write access scoped to the above bucket.
- An access key for `hooks-fyi`, exposed via sensitive Terraform outputs.

## State management

State is stored remotely in:
- **Bucket:** `hooks-fyi-tfstate` (versioned, AES256-encrypted, public access blocked).
- **Lock table:** `hooks-fyi-tflock` (DynamoDB, on-demand billing).
- **Region:** `us-east-1`.
- **Key pattern:** `projects/<project>/terraform.tfstate`.

Both backend resources are created once via `scripts/bootstrap-backend.sh`. The script is idempotent so re-running is safe.

> ⚠ State contains sensitive values (notably IAM access key secrets). Read access to `hooks-fyi-tfstate` should be restricted to the same humans/automation that can apply this repo.

## Authentication

GitHub Actions authenticates to AWS using long-lived access keys for an IAM user with administrative-equivalent permissions on the resources we manage, stored as repo secrets:

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID`     | CI access key id |
| `AWS_SECRET_ACCESS_KEY` | CI secret |

The CI user is **not** the same as `hooks-fyi`. `hooks-fyi` is an application service account managed by Terraform and has only S3 read-write permissions to one bucket. The CI user is an account-level admin (or scoped to "manage S3 + IAM in this account") and is created out-of-band.

> **Future work:** Replace the CI access keys with GitHub OIDC + an IAM role (`role-to-assume`). This eliminates long-lived secrets.

## CI/CD flows

Both workflows use a `matrix` over the list of projects so all projects are checked / applied per run. The matrix is currently hardcoded; switch to dynamic discovery (`find terraform/projects -mindepth 1 -maxdepth 1 -type d`) when the list grows.

### Plan (on PR)
Trigger: `pull_request` targeting `main`, when `terraform/projects/**` or workflow files change.
Per project in the matrix:
1. Checkout
2. Configure AWS credentials
3. `terraform fmt -check -recursive`
4. `terraform init`
5. `terraform validate`
6. `terraform plan -no-color -out=tfplan`
7. Comment plan output on the PR (one comment per project)

### Apply (on merge / manual)
Triggers:
- `push` to `main` when `terraform/projects/**` or workflow files change.
- `workflow_dispatch` (manual run from the Actions tab; lets you target a specific project).
Per project in the matrix:
1. Checkout
2. Configure AWS credentials
3. `terraform init`
4. `terraform plan -no-color -out=tfplan`
5. `terraform apply -auto-approve tfplan`

Apply runs serially per project via a GitHub Actions `concurrency` group keyed to the workflow + project so two merges can't race the same project's state.

## Bootstrap order (one-time, per AWS account)

1. Create the CI IAM user (admin-ish) **outside** this repo and capture its keys.
2. Run `./scripts/bootstrap-backend.sh` from a machine logged in to that account.
3. Add `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` as GitHub repo secrets.
4. Push to `main` (or rerun the apply workflow). CI takes over from here.

## Adding a new resource

1. Branch off `main`.
2. Decide which project it belongs to (or create a new one).
3. Add or extend a file in `terraform/projects/<project>/` matching the AWS service (`s3.tf`, `iam.tf`, …).
4. Open a PR. The plan workflow comments the diff per project.
5. Get review, merge. The apply workflow rolls it out.

## Reading sensitive outputs

```bash
cd terraform/projects/<project>
terraform init
terraform output -raw <output_name>
```
Requires read access to the state bucket. Don't commit, don't paste in chat.
