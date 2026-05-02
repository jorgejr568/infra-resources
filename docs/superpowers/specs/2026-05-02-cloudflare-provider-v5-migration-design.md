# Cloudflare Terraform Provider 4.52.7 → 5.x Migration — Design

## Goal

Migrate the repo from Cloudflare Terraform provider `~> 4.40` (currently locked to `4.52.7`) to `~> 5.0`. Every DNS record managed by this repo must remain in place — no destroy/create, no DNS outage. End state: `terraform plan` is a no-op, all 6 zones still resolve correctly.

## Non-goals

- Migrating any AWS provider version (separate effort).
- Migrating Terraform CLI version (stay on 1.10.5).
- Adopting v5-only features beyond what tf-migrate produces (e.g., new `cloudflare_dns_record` `data` nested attribute) — keep diffs minimal.
- Re-architecting the `cloudflare-default-server-subdomains` module — only update its resource type/attributes.
- Changing the dependabot ignore rule for Cloudflare major bumps. The 5→6 bump remains out of scope; we keep the rule.

## Constraints

- Single PR. Cloudflare provider can only be pinned to one major version at a time, so partial migration isn't possible.
- Must produce a no-op `terraform plan` against current live state. Any plan that shows `+`/`-` lines on a `cloudflare_record` or `cloudflare_dns_record` is a hard stop.
- S3 state bucket has versioning enabled — recovery path if anything goes wrong post-merge.
- Pre-req for tf-migrate: provider `>= 4.52.5`. Lockfile is at `4.52.7` ✓.

## Migration mechanics

Source: official [Cloudflare tf-migrate v1.0.1](https://github.com/cloudflare/tf-migrate) and the [v5 upgrade guide](https://github.com/cloudflare/terraform-provider-cloudflare/blob/main/docs/guides/version-5-upgrade.md).

Two layers:

1. **Configuration (HCL) transformation — done by `tf-migrate`.**
   - Renames `cloudflare_record` → `cloudflare_dns_record` everywhere.
   - Generates `moved {}` blocks for each rename so state addresses don't drift.
   - Updates attribute names that changed in v5 (notably: `name` now requires the full FQDN, `value` is consolidated to `content`, removed attributes like `hostname` / `allow_overwrite` are dropped — none of which we currently use).
   - Updates `required_providers` constraints to v5.

2. **State schema upgrade — done by the v5 provider's built-in `UpgradeState`/`MoveState`.**
   - Runs automatically when `terraform plan`/`apply` first executes against v4-state with v5-provider.
   - No manual `terraform state mv` or `import` blocks needed for resources covered by the upgrader (which includes `cloudflare_record` → `cloudflare_dns_record`).

## Repo inventory affected

**Files using `cloudflare_record`:**
- `terraform/modules/cloudflare-default-server-subdomains/main.tf` — 2 resources (`a`, `aaaa`), each `for_each` over caller's `subdomains`. Used by **6 module instances** (proxied: hooks-fyi, rentivo, joy-living, eic-seminarios, jorgejunior_dev, j_jr_app; unproxied: eic-seminarios `s3-beta`).
- `terraform/projects/rentivo/cloudflare.tf` — `rentivo_dmarc` (TXT), `rentivo_ses_dkim` (CNAME, `for_each`), `rentivo_mail_mx` (MX), `rentivo_mail_spf` (TXT).
- `terraform/projects/jorgejunior/cloudflare.tf` — `jorgejunior_dev_mx` (MX, `for_each`), `j_jr_app_vercel` (CNAME, `for_each`).

**Files using `data "cloudflare_zone"`:** all 6 cloudflare.tf files. Per the upgrade guide, the data source remains in v5 with minor attribute changes (we only consume `.id` — likely unaffected, but tf-migrate will handle any required transform).

**Provider pins to update:**
- `terraform/versions.tf`
- `terraform/projects/hooks-fyi/versions.tf`
- `terraform/projects/rentivo/versions.tf`
- `terraform/projects/joy-living/versions.tf`
- `terraform/projects/eic-seminarios/versions.tf`
- `terraform/projects/jorgejunior/versions.tf`
- `terraform/modules/cloudflare-default-server-subdomains/versions.tf`

`~> 4.40` → `~> 5.0` in all 7 files. tf-migrate handles this automatically.

## Sequence

Single PR. One branch: `feat/cloudflare-provider-v5`.

1. **Install tf-migrate** locally. Try `brew install cloudflare/cloudflare/tf-migrate` first; fall back to GitHub release binary for `darwin_arm64` from `cloudflare/tf-migrate` v1.0.1.
2. **Dry run:** `tf-migrate migrate --source-version v4 --target-version v5 --dry-run` from inside `terraform/`. Inspect proposed config diffs and the proposed `moved {}` blocks.
3. **Real run:** `tf-migrate migrate --source-version v4 --target-version v5`. Inspect git diff.
4. **Manual review of generated HCL.** Look for:
   - All 6 cloudflare.tf files updated.
   - The shared module's `main.tf` updated.
   - All 7 versions.tf files have new `~> 5.0` pin.
   - `moved {}` blocks generated for each renamed `cloudflare_record` resource. For module-internal resources, the moves should target the new module-internal address.
   - No new resources introduced unintentionally.
5. **Refresh lockfile:** `docker run --rm -v "$PWD":/work -w /work/terraform hashicorp/terraform:1.10.5 init -upgrade -backend=false`. Commit the new `.terraform.lock.hcl`.
6. **Local plan against live state.** Run with real backend creds:
   ```bash
   AWS_PROFILE=<profile> CLOUDFLARE_API_TOKEN=<token> \
     TF_VAR_server_ipv4=<ip> TF_VAR_server_ipv6=<ip> \
     terraform -chdir=terraform plan
   ```
   Expected: `Plan: 0 to add, 0 to change, 0 to destroy.` plus moved-state output. Anything else is a hard stop — investigate and fix before pushing.
7. **Commit, push, open PR.** PR description includes the local plan output for the reviewer to verify the CI plan matches.
8. **CI plan re-runs the same flow** against live state. If CI plan is also no-op, merge.
9. **Merge** triggers `terraform-apply`, which writes the upgraded state to S3.
10. **Post-merge verification.** Open one zone in Cloudflare dashboard; spot-check a record (e.g., `www.hooks.fyi`) is unchanged.

## Risk and rollback

- **Most likely failure mode:** local plan shows non-no-op diffs. Causes:
  - tf-migrate didn't generate a `moved {}` block for some resource (file an issue upstream; manually add the block).
  - An attribute change isn't auto-handled (manually adjust the HCL).
  - For-each key drift (very unlikely — the `subdomains` toset values are byte-identical pre/post).
- **Worst case (if merged with bad plan):** state file in S3 has resources destroyed/recreated. DNS may be served by a fresh-IDs record briefly. Cloudflare's API doesn't drop records on update, but recreate-during-apply momentarily breaks resolution.
- **Rollback path:**
  1. S3 versioning preserves the v4-schema state file. Locate the previous version (`aws s3api list-object-versions --bucket jorgejr568-aws-resources-tfstate --prefix aws-resources.tfstate`) and restore.
  2. Revert the merge commit on `main` so HCL goes back to v4.
  3. `terraform-apply` then runs against restored state with restored HCL — back to status quo.
- **Pre-merge gate:** local plan + CI plan must both be no-op. No exceptions.

## Testing

- **Local plan:** the gate. Must be no-op.
- **CI plan:** second gate. Must match the local plan exactly.
- **CI tflint:** continues to run. tflint may not yet have v5 cloudflare ruleset support; if it complains about unknown resources, suppress with a one-line comment in `terraform/.tflint.hcl`. Do NOT block on tflint regressions for new resource types.
- **CI trivy-config:** continues to run. Trivy may not yet recognize `cloudflare_dns_record`; same handling.
- **Apply:** the actual state migration happens here. Apply log should show "state has been migrated" or similar; resource count unchanged.
- **Post-apply spot check:** one DNS lookup per zone (e.g., `dig www.hooks.fyi @1.1.1.1`) confirms records still resolve. Optional but worth a minute.

## Out-of-scope follow-ups (mention only)

- Removing the dependabot ignore rule for Cloudflare major bumps (PR #28). Now-on-5.x means the next major would be 6.x — keep the rule, since 5→6 will also be a planned migration.
- Cleaning up the `moved {}` blocks generated by tf-migrate after a couple of applies (same pattern as PR #15 for the polish series).
- Adopting any new v5-only attributes/resources. Stay minimal in this PR.
