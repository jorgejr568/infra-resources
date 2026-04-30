# Cutover runbook: Pulumi → Terraform for Cloudflare DNS

This runbook covers the *manual* steps that bracket the PR. The PR itself is purely code; the cutover is what makes it live.

## Pre-merge — set GitHub repo variables (once)

Required because the new Terraform vars are sourced from `vars.*`:

```bash
# from inside the cloudflare-resources/ directory, while it still has Pulumi config:
SERVER_IPV4=$(pulumi config get server:ipv4 --stack production --show-secrets)
SERVER_IPV6=$(pulumi config get server:ipv6 --stack production --show-secrets)
CF_ACCOUNT_ID=$(pulumi config get cf:accountId --stack production --show-secrets)

gh variable set SERVER_IPV4 -b "$SERVER_IPV4" -R jorgejr568/aws-resources
gh variable set SERVER_IPV6 -b "$SERVER_IPV6" -R jorgejr568/aws-resources
gh variable set CLOUDFLARE_ACCOUNT_ID -b "$CF_ACCOUNT_ID" -R jorgejr568/aws-resources
```

Verify: `gh variable list -R jorgejr568/aws-resources` should now include `SERVER_IPV4`, `SERVER_IPV6`, `CLOUDFLARE_ACCOUNT_ID`.

## Pre-merge — set GitHub repo secret (once)

```bash
# Reuse the same token the Pulumi side used. If you don't have it locally,
# regenerate at https://dash.cloudflare.com/profile/api-tokens and rotate.
gh secret set CLOUDFLARE_API_TOKEN -R jorgejr568/aws-resources
```

## Pre-merge — confirm `terraform-plan` PR comment shows ~75 creates and 0 destroys

If the count is different, STOP and reconcile with the audit in Task 10 Step 6 before continuing.

## At merge time — destroy the Pulumi stack first

This is the brief-downtime moment:

```bash
cd cloudflare-resources
pulumi stack select production
pulumi destroy --stack production --yes
```

Pulumi will tear down all Cloudflare records it manages, including the 3 obsolete `vistadamontanha.com.br` records (the lookup of that zone may fail if the zone is gone — Pulumi will report an error during destroy; if so, manually remove those resources from Pulumi state with `pulumi state delete <urn>` for each `vista-da-montanha-*` URN, then re-run destroy).

Note: Pulumi only manages DNS *records*, not the zones themselves. The zones (and registrar/nameserver settings, SSL/TLS, page rules, workers, etc.) are unaffected.

## At merge time — merge the PR

Once `pulumi destroy` reports success, merge the PR. The `terraform-apply` workflow will run `terraform apply` and recreate the 75 records the new Terraform owns. (vista-da-montanha is intentionally not in the new set.)

## Post-merge — verify

- Visit the Cloudflare dashboard for each zone, confirm record count.
- For proxied zones: `dig +short A hooks.fyi` should resolve to a Cloudflare proxy IP (e.g. starts with `104.` or `172.`), not the origin.
- `terraform output -raw hooks_fyi_zone_id` etc. should return the same zone IDs Pulumi used to export.

## Post-merge — clean up Pulumi side

After confirming the new records work:

```bash
# Delete the (now-empty) Pulumi stack
cd cloudflare-resources
pulumi stack rm production --yes

# Archive the old GitHub repo (does NOT delete it)
gh repo archive jorgejr568/cloudflare-resources

# Optional: rename this repo
gh repo rename infra-resources -R jorgejr568/aws-resources
git -C /Users/j/src/jorgejr568/aws-resources remote set-url origin git@github.com:jorgejr568/infra-resources.git
```

## Rollback plan

If `terraform apply` fails partway through:
1. The Cloudflare records that did get created are now in Terraform state — leave them.
2. Fix the failing config in a follow-up commit, push, let `terraform-apply` run again.
3. If you need to roll *all the way* back to Pulumi: `cd cloudflare-resources && pulumi up --stack production` would re-create them, but only if the Pulumi tree is still in this repo (i.e. the cutover PR hasn't deleted it yet — see Task 13). Once Task 13 lands, rollback means restoring `cloudflare-resources/` from the pre-deletion commit and `pulumi up`.
