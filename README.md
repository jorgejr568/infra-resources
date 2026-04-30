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
   - `CLOUDFLARE_ACCOUNT_ID`
4. **Push to `main`** — the apply workflow runs automatically.
5. **For changes thereafter**, open a PR. The plan workflow comments the diff. Merge to apply.

## Layout

- `terraform/projects/<project>/` — one Terraform child module per project. Each project owns its AWS *and* its Cloudflare resources. Projects: `eic-seminarios`, `hooks-fyi`, `jorgejunior` (jorgejunior.dev + j-jr.app), `joy-living`, `rentivo`.
- `terraform/` — root module: `main.tf`, `providers.tf`, `versions.tf`, `backend.tf`, `outputs.tf`, `variables.tf`. One state for everything.
- `.github/workflows/` — `terraform-plan.yml` (PR), `terraform-apply.yml` (main).
- `scripts/` — operational scripts (state backend bootstrap).
- `docs/` — architecture and decision docs, plus implementation plans under `docs/superpowers/plans/`.
