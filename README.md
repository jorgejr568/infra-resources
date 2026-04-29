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
