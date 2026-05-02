# Polish `infra-resources` — Design

## Goal

Tighten the repo on five axes — DRY refactor of repeated Cloudflare DNS patterns, removal of dead code, CI hardening, dependency version bumps, and documentation cleanup — without changing any deployed AWS or Cloudflare resources. Every step must produce a `terraform plan` that is a no-op against current state.

## Non-goals

- Renaming the legacy `aws-resources` strings (state bucket / lock table / state key / provider tag) — separate effort, requires state migration.
- Migrating CI from long-lived AWS keys to GitHub OIDC — separate effort, called out in `ARCHITECTURE.md` as future work.
- Cloudflare provider 4.x → 5.x major upgrade — resource renames (`cloudflare_record` → `cloudflare_dns_record`) make this a real migration, not a polish.
- Adding an S3 lifecycle policy on the state bucket — out of scope this round.
- Adding ADRs, CODEOWNERS, LICENSE.

## Constraints

- All changes must produce a no-op `terraform plan` against the live state. Any resource renames inside child modules use `moved {}` blocks.
- One logical concern per PR; PRs land in the order listed under "Sequencing" below.
- Don't touch the `aws-resources` legacy naming — it's load-bearing for the running state backend.

---

## Section 1 — DRY: Cloudflare default-server subdomain module

### Problem

Five projects each repeat the same pattern: `for_each` over a `toset` of subdomain names, emitting one `cloudflare_record` of type `A` plus one of type `AAAA`, both pointing at `var.server_ipv4` / `var.server_ipv6`, both commented "Terraform managed record". Most are proxied; `eic-seminarios` has one unproxied subset (`s3-beta`) that follows the same shape with a different `proxied` flag and a different comment.

### Solution

Introduce a small reusable child module at `terraform/modules/cloudflare-default-server-subdomains/`. The module emits the A+AAAA pair pointing at the default origin server; `proxied` is an optional boolean (default `true`) so both proxied and unproxied callers can share it.

**Interface:**

```hcl
module "cf_proxied_<scope>" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.<x>.id
  subdomains = toset(["@", "www", ...])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
  # proxied defaults to true; pass false for DNS-only records
  # comment defaults to "Terraform managed record"
}
```

**Module internals:** `variables.tf`, `versions.tf`, `main.tf` (two `cloudflare_record` resources named `a` and `aaaa`, each with `for_each = var.subdomains`). No outputs.

**State preservation:** Each project's `cloudflare.tf` gets `moved {}` blocks for every renamed resource address. Example for `hooks-fyi`:

```hcl
moved {
  from = cloudflare_record.hooks_fyi_a
  to   = module.cf_proxied_hooks_fyi.cloudflare_record.a
}
moved {
  from = cloudflare_record.hooks_fyi_aaaa
  to   = module.cf_proxied_hooks_fyi.cloudflare_record.aaaa
}
```

`for_each` keys are preserved because the module re-uses the same `toset` values.

### Scope of migration

| Project | Migrate? | Notes |
|---|---|---|
| `hooks-fyi` | yes | `["@", "www"]`, proxied |
| `rentivo` | yes | `["@", "www"]`, proxied |
| `joy-living` | yes | `["@", "www", "api"]`, proxied |
| `eic-seminarios` (proxied) | yes | `["beta", "mail-beta", "console-s3-beta"]` |
| `eic-seminarios` (unproxied `s3-beta`) | yes | Second module instance with `proxied = false` and a custom DNS-only comment |
| `jorgejunior` (`jorgejunior.dev`) | yes | 16-element subdomain set, proxied |
| `jorgejunior` (`j-jr.app`) | yes | 8-element subdomain set, proxied |
| `jorgejunior` Vercel CNAMEs | **no** | Different type/target. Stays inline. |
| MX / TXT / DKIM CNAMEs | **no** | Project-specific, single resources, no DRY benefit. |

### Trade-off documented

`ARCHITECTURE.md` says "projects own their resources." The new module is a *primitive* — equivalent in role to `aws_s3_bucket_versioning` or `aws_s3_bucket_public_access_block`, not a cross-project boundary. Document that distinction in the architecture doc.

---

## Section 2 — Dead code removal

### What

Remove `var.cloudflare_account_id` end-to-end:

- `terraform/variables.tf` — delete the variable block.
- `terraform/outputs.tf` — delete the `output "cloudflare_account_id"` passthrough.
- `.github/workflows/pr-checks.yml` — delete the `TF_VAR_cloudflare_account_id` env line.
- `.github/workflows/terraform-apply.yml` — delete the `TF_VAR_cloudflare_account_id` env line.
- `README.md` — delete `CLOUDFLARE_ACCOUNT_ID` from the repo-vars list.
- `docs/ARCHITECTURE.md` — remove the row from the Cloudflare authentication table.

The repo-level GitHub variable `CLOUDFLARE_ACCOUNT_ID` can stay set in GitHub (we don't manage GitHub config from Terraform); it just becomes unreferenced.

### Plan impact

The variable has never been used by any resource. Removing it changes nothing in state. `terraform plan` after removal: no changes.

---

## Section 3 — CI hardening

### Changes to `.github/workflows/pr-checks.yml`

Add two new lint jobs that run in parallel with `terraform-plan` (gated by the same `changes` filter):

**`tflint` job:**
- Uses `terraform-linters/setup-tflint@v4`.
- Working dir `terraform/`.
- Runs `tflint --init` then `tflint --recursive --format=compact`.
- Tflint config at `terraform/.tflint.hcl` enabling the `terraform`, `aws`, and `cloudflare` rulesets at default severity. (`tflint` recursive picks up child modules.)

**`trivy-config` job:**
- Uses `aquasecurity/trivy-action@0.28.0` with `scan-type: config` and `scan-ref: terraform/`.
- Severity: `HIGH,CRITICAL`. Failure on findings.
- A `.trivyignore` file at repo root exists but is empty initially — placeholder for future intentional suppressions with comments explaining each.

Update the existing `plan` aggregation job to require both new jobs as well: `needs: [changes, terraform-plan, tflint, trivy-config]` and treat `success | skipped` as PASS for each.

### Changes to `.github/workflows/terraform-apply.yml`

Add a `terraform fmt -check -recursive` step **before** `terraform init`, with no `continue-on-error`. Apply path was previously fmt-blind on `workflow_dispatch`.

### Pre-commit configuration

Add `.pre-commit-config.yaml` at repo root using `antonbabenko/pre-commit-terraform`:

- `terraform_fmt`
- `terraform_validate` (with `--args=-no-color`)
- `terraform_tflint` (so local matches CI)

Document the install in README:

```bash
brew install pre-commit
pre-commit install
```

Pre-commit is opt-in for contributors; CI remains the source of truth.

---

## Section 4 — Version bumps

### Terraform

- `terraform/versions.tf`: `required_version = ">= 1.10.0, < 2.0.0"`.
- `.tool-versions`: `terraform 1.10.5`.
- `.github/workflows/pr-checks.yml`: `terraform_version: 1.10.5`.
- `.github/workflows/terraform-apply.yml`: `terraform_version: 1.10.5`.

(Stay on the 1.10.x series — it's GA and stable. Don't jump to 1.11+ until adoption settles.)

### AWS provider

- `terraform/versions.tf`: `aws = "~> 5.70"`.
- All five `terraform/projects/*/versions.tf` that declare `aws`: same bump.
- Run `terraform init -upgrade` locally to refresh `.terraform.lock.hcl`. Commit the lockfile.

### Cloudflare provider

- **No change this round.** Stays at `~> 4.40`. Tracked as future work in `ARCHITECTURE.md`.

### Validation

After each provider/Terraform bump, run `terraform init -upgrade && terraform validate && terraform plan`. The plan must be empty.

---

## Section 5 — Documentation

### `README.md`

Slim further. Final shape:

- One-paragraph project description.
- Quick-start: bootstrap, secrets, vars, `git push`.
- "Local development" section: `pre-commit install`, `terraform fmt -recursive`.
- Pointer to `docs/ARCHITECTURE.md` for everything else.

Anything explanatory (project list, layout, adding-a-project howto) **only** lives in `ARCHITECTURE.md`. The current README already does this well; mainly add the local-dev paragraph and trim any duplicated facts.

### `docs/ARCHITECTURE.md`

- Update the **Repository layout** tree to include `terraform/modules/cloudflare-default-server-subdomains/`.
- Add a short subsection under "One root module, many project sub-modules" titled "Shared primitive modules" that explains the role of `terraform/modules/`: small reusable building blocks (current sole occupant: `cloudflare-default-server-subdomains`), distinct from per-project child modules under `terraform/projects/`.
- Update the **Cloudflare authentication** table to remove `CLOUDFLARE_ACCOUNT_ID`.
- Update the **CI/CD flows** section to mention the new `tflint` and `trivy-config` PR jobs and the new fmt step in apply.
- Leave OIDC future-work note as-is.

### Out of scope

- No CONTRIBUTING.md (the new README local-dev section covers it).
- No ADRs.
- No CODEOWNERS / LICENSE.

---

## Sequencing (one PR per item, in order)

1. **PR 1 — Version bumps (F).** Smallest, exercises CI end-to-end with new versions. Confirms infra apply still no-ops on the new toolchain before any structural change.
2. **PR 2 — Dead code removal (C).** Pure deletion; no plan impact.
3. **PR 3 — DRY: cloudflare-default-server-subdomains module (B).** Risky-looking but state-preserving via `moved` blocks. Plan must be empty.
4. **PR 4 — CI hardening (D).** Adds `tflint`, `trivy config`, fmt on apply, pre-commit.
5. **PR 5 — Documentation (G).** Reflects all prior changes. Last so docs match reality.

Each PR runs the existing plan workflow; merge only after the PR plan comment shows no resource changes (PR 3) or new lint jobs all green (PR 4).

## Testing

- **Per PR:** PR's own plan job must show `0 to add, 0 to change, 0 to destroy` (PRs 1–3) and all lint/scan jobs green.
- **PR 3 specifically:** verify each `moved {}` block resolves cleanly — read the plan comment and confirm zero `+`/`-` lines for any `cloudflare_record.*` resource.
- **Post-merge of each:** the apply workflow on `main` must succeed with the same no-op plan.

## Risks

- **Cloudflare for_each key drift in PR 3:** `moved {}` only works if old and new addresses share the same `for_each` key. The module re-uses the input `toset`, so keys are byte-identical to the originals. Verified by inspecting each project's existing `local.<x>_proxied_subdomains` and confirming it maps 1:1 to the module's `var.subdomains`.
- **AWS provider 5.60 → 5.70 minor bump:** semver-safe per HashiCorp; no resource schema removals expected. Validate with `terraform plan`.
- **Terraform 1.9.8 → 1.10.x:** state file format is forward-compatible within the 1.x series; CI and local toolchain bump together so no version skew between operators.
- **`tflint` / `trivy config` will likely flag findings on first run.** Triage at PR-4 review time: fix anything cheap; for the rest, suppress with comments in `.tflint.hcl` / `.trivyignore` and capture the rationale in the PR description.
