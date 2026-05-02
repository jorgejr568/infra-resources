# AWS Terraform Provider 5.x → 6.0 Migration — Design

## Goal

Bump the AWS Terraform provider from `~> 5.70` (lockfile at `5.100.0`) to `~> 6.0`. Every managed AWS resource (S3 buckets, IAM users/policies/keys, SES domain) stays in place — `terraform plan` is a clean no-op.

## Non-goals

- Migrating Cloudflare provider further (already on 5.19.1 from PR #29).
- Migrating Terraform CLI version (stay on 1.10.5).
- Adopting v6-only features (most notably the new per-resource `region` argument added by Enhanced Region Support).
- Removing the dependabot ignore rule for AWS major bumps (PR #28). Keep it; the next major (7.x) will also be a planned migration.
- Adding new resources, changing tags, or making any non-migration changes.

## Constraints

- Single PR.
- Must produce a no-op `terraform plan` against current live state.
- S3 state bucket has versioning enabled — same recovery path as the cloudflare migration.
- Pre-req per the upgrade guide: be on the latest 5.x first. Lockfile is at `5.100.0`, which is 5.x latest at time of writing — pre-req met.

## Surface area inventory

**Resources we manage that the v6 upgrade guide mentions:**

| Resource | v6 change | Our exposure |
|---|---|---|
| `aws_s3_bucket` | New `bucket_region` attribute; old `region` repurposed for Enhanced Region Support. | We don't set `region` on buckets — **no code change required**. |

**Resources we manage that the v6 upgrade guide does NOT mention** (treated as schema-stable across the major bump):

- `aws_s3_bucket_public_access_block` (×2)
- `aws_s3_bucket_server_side_encryption_configuration` (×2)
- `aws_s3_bucket_versioning` (×2)
- `aws_s3_bucket_ownership_controls` (×2)
- `aws_iam_user` (×2)
- `aws_iam_policy` (×3 — hooks-fyi-request-files-rw, rentivo-files-rw, rentivo-ses-send-naoresponder)
- `aws_iam_user_policy_attachment` (×3)
- `aws_iam_access_key` (×2)
- `aws_ses_domain_identity` (rentivo)
- `aws_ses_domain_dkim` (rentivo)
- `data "aws_iam_policy_document"` (×3)

**v6 changes that don't affect us:**

- Removed provider arguments (`endpoints.opsworks`, `endpoints.simpledb`, `endpoints.sdb`, `endpoints.worklink`) — none used.
- `TypeNullableBool` validation update — none of the listed resources/attributes used.
- OpsWorks Stacks / SimpleDB / Worklink / Elastic Transcoder / CloudWatch Evidently removals — none used.
- Resource-specific changes for `aws_db_instance`, `aws_eks_addon`, etc. — none used.

## Migration mechanics

This migration is far simpler than the Cloudflare one. There are no resource type renames, no attribute renames affecting us, and no `moved {}` blocks needed.

1. **Provider pin update.** Change `version = "~> 5.70"` to `version = "~> 6.0"` in 3 `versions.tf` files:
   - `terraform/versions.tf` (root)
   - `terraform/projects/hooks-fyi/versions.tf`
   - `terraform/projects/rentivo/versions.tf`
   - The 3 CF-only projects (`joy-living`, `jorgejunior`, `eic-seminarios`) and the `cloudflare-default-server-subdomains` module don't pin AWS — no change.
2. **Lockfile refresh.** `docker run hashicorp/terraform:1.10.5 init -upgrade -backend=false` rewrites `.terraform.lock.hcl` to pin the latest 6.x.
3. **Validate.** `terraform validate` should pass with no errors. If it fails, the error message names the resource/attribute that broke; fix and re-validate.
4. **Plan via CI.** Push as a PR; CI's `terraform-plan` runs against live state with the new provider. Plan must be no-op.

## Sequence

Single PR. One branch: `feat/aws-provider-v6`.

1. Branch off updated `main`.
2. Edit the 3 `versions.tf` files: bump pin.
3. Run lockfile refresh via Docker.
4. Run `terraform fmt -check -recursive` and `terraform validate`.
5. Commit, push, open PR.
6. Watch CI; if `terraform-plan` PR comment shows anything other than `Plan: 0 to add, 0 to change, 0 to destroy.`, do NOT merge — investigate.
7. Merge. `terraform-apply` runs against live state.
8. Post-apply spot check: `aws s3 ls` and `aws iam get-user --user-name hooks-fyi` to confirm resources still respond.

## Risk and rollback

- **Likely failure mode:** silent attribute schema drift. Even though no resource is listed in the upgrade guide's per-resource sections, an attribute's normalisation behaviour may have changed (e.g., default tags merging order). The CI plan output is the gate.
- **If plan shows drift:** triage the diff. Common causes:
  - Default tags interaction — if a tag now appears that wasn't tracked before (or vice versa), update `providers.tf` accordingly.
  - Attribute reordering in nested blocks — usually harmless, but read the diff.
  - Computed-default change (e.g., bucket ownership defaults) — pin the value explicitly.
- **Rollback:** S3 state versioning preserves the v5-schema state file. Same recovery procedure as the Cloudflare migration: revert the merge commit, restore the previous state version via `aws s3api copy-object`.
- **Pre-merge gate:** local `terraform validate` passes (mandatory) plus CI plan is no-op (mandatory). No exceptions.

## Testing

- **Local validate:** `terraform validate` via Docker. Must pass.
- **CI plan:** `Plan: 0 to add, 0 to change, 0 to destroy.`
- **CI tflint:** continues to run. If it complains about new attributes (e.g., `bucket_region`), suppress with rationale in `terraform/.tflint.hcl`.
- **CI trivy-config:** continues to run. Same handling.
- **Apply:** must succeed with no resource changes.
- **Post-apply spot check:** `aws s3api list-buckets` and `aws iam list-users` confirm resources are still present and accessible.

## Out-of-scope follow-ups (mention only)

- Adopting v6's per-resource `region` argument for the rare case where we want a resource in a different region from the provider default. Not currently a concern (everything is `us-east-1`).
- Cleaning up the dependabot ignore rule for AWS major bumps after one or two minor releases land cleanly.
- Migrating any provider-level `default_tags` reformat that v6 may suggest. Out of scope.
