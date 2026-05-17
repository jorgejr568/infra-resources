# Security policy

## In scope

This policy covers the contents of this repository:

- Terraform configuration (`terraform/`)
- GitHub Actions workflows (`.github/workflows/`)
- Operational scripts (`scripts/`)

## Not in scope

The deployed services managed by this repo (e.g. `hooks.fyi`, `rentivo.com.br`, `joyliving.com.br`, `jorgejunior.dev`, `j-jr.app`, `eic-seminarios.com`) are **separate products** owned by their respective project teams. Security reports about those services should go to those owners directly, not here.

## How to report a vulnerability

1. **Preferred:** open a [private security advisory](https://github.com/jorgejr568/infra-resources/security/advisories/new) on this repository.
2. **Fallback:** email the maintainer at the address in the repo's `git log`. Include `[security]` in the subject line.

Please do **not** open public issues for security bugs.

## What to expect

- **Acknowledgement:** within 7 days.
- **Triage and decision:** within 30 days. Either a fix, a mitigation plan, or a documented rationale for declining.

This is a personal infrastructure repository. There is no funded bug-bounty programme; reports are handled best-effort.

## Examples of valid security findings

- A secret (AWS key, Cloudflare token, etc.) committed to this repo's history.
- An IAM policy in `terraform/projects/*/iam.tf` granting more access than the comment / sid implies.
- An S3 bucket configuration that exposes objects publicly.
- A GitHub Actions workflow vulnerable to script injection (e.g. interpolating untrusted PR titles into `run:` blocks).
- A vulnerable version of a third-party action used by `pr-checks.yml` or `terraform-apply.yml`.
- A vulnerable Terraform provider version that affects this repo's resources.

## Not security findings

- Code-quality concerns (open a regular issue or PR).
- Cosmetic or naming preferences.
- Findings about a service running at one of the listed domains (report to that service's owner).
- Generic "you should use OIDC instead of access keys" — already tracked as future work in `docs/ARCHITECTURE.md`.
