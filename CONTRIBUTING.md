# Contributing

Thanks for considering a contribution. This is a personal infra repo — most changes will come from the maintainer, but bug fixes and improvements are welcome.

## Before you start

- Install [pre-commit](https://pre-commit.com) and run `pre-commit install` once. The pre-commit config (`.pre-commit-config.yaml`) wires up the same `terraform_fmt`, `terraform_validate`, and `tflint` checks that run in CI.
- Use Terraform `1.10.5` locally (matches `.tool-versions`). If you don't have it, the easiest path is Docker:
  ```bash
  docker run --rm -v "$PWD":/work -w /work/terraform hashicorp/terraform:1.10.5 fmt -check -recursive
  ```

## Workflow

1. Fork the repo on GitHub.
2. Branch from `main`.
3. Make your change. Stay inside `terraform/` (and/or `.github/workflows/`) — README, ARCHITECTURE, scripts, and policy files are also fair game.
4. Run locally:
   ```bash
   cd terraform
   terraform fmt -recursive
   terraform init -backend=false && terraform validate
   tflint --recursive --format=compact
   ```
5. Commit with a [Conventional Commits](https://www.conventionalcommits.org/) prefix: `feat:`, `fix:`, `chore:`, `ci:`, `docs:`, `refactor:`, `test:`.
6. Push and open a PR against `main`.
7. CI runs `terraform-plan`, `tflint`, and `trivy-config`. Wait for the plan PR comment.
8. The maintainer reviews — both the diff and the plan output — and merges.

## Plan rules of thumb

- **Refactors and doc / CI changes must produce a no-op `terraform plan`.** If you're refactoring, use `moved {}` blocks to preserve state.
- **Functional changes** (new resources, schema bumps, lifecycle policies, etc.) should describe the intended diff in the PR body so the reviewer knows what to look for.
- **Trivy or tflint findings** are CI failures by design. If a finding is a deliberate choice, suppress it in `.tflint.hcl` or `.trivyignore` with a one-line `# why:` comment in the same PR.

## Out of bounds

Please don't submit:

- Changes to *another* project's resources without coordinating with that project's owner.
- Renames of AWS resources (`aws_s3_bucket`, `aws_iam_user`, `aws_iam_policy` `name` attributes). These are tied to live state and require a separate state-migration plan.
- Removal of the customer-named project modules (`rentivo`, `joy-living`, `eic-seminarios`).
- Major version bumps of the AWS or Cloudflare provider — those are separate plans, not drive-by changes.

## Reporting bugs

Open a regular issue. For security bugs, follow `SECURITY.md` instead.
