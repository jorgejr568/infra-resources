# eic-seminarios AWS resources import — design

**Date:** 2026-05-30
**Status:** Approved (pending spec review)
**Account:** `730335335283` (single account; provider differs only by `default_tags.Project`)
**Region:** `us-east-1`

## Goal

Bring the existing `eic-seminarios` AWS footprint under Terraform in this repo so it
works with `terraform plan`/`apply`, without disrupting live data, the verified SES
domain, or live credentials. The project already manages Cloudflare DNS for
`eic-seminarios.com`; this adds the AWS side.

## Migration strategy

**Import, not greenfield.** The Cloudflare port (2026-04-30) used a greenfield
destroy/recreate. That is unacceptable here: the buckets hold real objects, the SES
domain is verified, and the IAM keys are live. We use Terraform 1.10 native
`import {}` blocks committed in config so the import is reviewable in the PR, shows up
in `plan`, runs on the first `apply`, and the blocks are deleted in a follow-up commit
once state is established.

**Definition of done:** `terraform plan` reports only the imports with **zero resource
changes** (no create/update/replace/destroy) — i.e. the config exactly matches live
state.

## Provider wiring

- `providers.tf`: add a fourth project alias
  ```hcl
  provider "aws" {
    alias  = "eic_seminarios"
    region = var.aws_region
    default_tags { tags = { ManagedBy = "terraform", Repo = "aws-resources", Project = "eic-seminarios" } }
  }
  ```
- `main.tf`: add `aws = aws.eic_seminarios` to the existing `eic_seminarios` module's
  `providers` map (currently it only receives `cloudflare`).
- `projects/eic-seminarios/versions.tf`: add `aws = { source = "hashicorp/aws", version = "~> 6.0" }`
  alongside the existing `cloudflare ~> 5.0`.

## Resources

### `s3.tf`

**Bucket `eic-seminarios`** (private app bucket):
- `aws_s3_bucket`
- `aws_s3_bucket_versioning` → `Enabled`
- `aws_s3_bucket_server_side_encryption_configuration` → `AES256`, `bucket_key_enabled = true`
- `aws_s3_bucket_public_access_block` → all four `true`
- `aws_s3_bucket_ownership_controls` → `BucketOwnerEnforced`
- No policy / website / cors / lifecycle / tags.

**Bucket `guide.eic-seminarios.com`** (public static-website bucket):
- `aws_s3_bucket`
- `aws_s3_bucket_server_side_encryption_configuration` → `AES256`, `bucket_key_enabled = false`
- `aws_s3_bucket_public_access_block` → all four `false`
- `aws_s3_bucket_ownership_controls` → `BucketOwnerEnforced`
- `aws_s3_bucket_website_configuration` → index `index.html`, error `index.html`
- `aws_s3_bucket_policy` → public `s3:GetObject` (`PublicReadGetObject`)
- No versioning.

Note: AWS reports `BlockedEncryptionTypes: [SSE-C]` on these buckets. This is an
account/default-level attribute the `~> 6.0` provider does not model on
`aws_s3_bucket_server_side_encryption_configuration`; it will not appear as drift. If
`plan` shows drift here, revisit.

### `iam.tf`

**User `eic-seminarios`** (path `/`):
- `aws_iam_user`
- `aws_iam_policy` `eic-seminarios-ses` — attached managed policy, verbatim document:
  - `ses:SendEmail`/`ses:SendRawEmail` on `*` conditioned to `ses:FromAddress` in
    {`no-reply@eic-seminarios.com`, `naoresponder@eic-seminarios.com`}
  - S3 rw (`GetBucketLocation`,`ListBucket`,`GetObject`,`PutObject`,`DeleteObject`) on
    `arn:aws:s3:::eic-seminarios` + `/*`
  - `logs:DescribeLogGroups`/`DescribeLogStreams` on `*`
  - `logs:CreateLogGroup`/`CreateLogStream`/`PutLogEvents`/`PutRetentionPolicy` on
    `log-group:seminarios-eic` + `:*`
- `aws_iam_user_policy_attachment`
- **Two imported access keys** via `aws_iam_access_key`:
  - `AKIA2UC3A2NZQRMLBG3Q` (2026-01-15)
  - `AKIA2UC3A2NZTNO5HVHT` (2024-10-18)
  - Imported, not created → no `secret`/`ses_smtp_password` outputs (you already hold
    them). The 2024 key is kept as-is; prune as a future cleanup if confirmed unused.

**User `eic-seminarios-guide-uploader`** (path `/`):
- `aws_iam_user`
- `aws_iam_user_policy` `S3GuideSync` — inline, verbatim document:
  - S3 (`PutObject`,`DeleteObject`,`ListBucket`) on `guide.eic-seminarios.com` + `/*`
  - `cloudfront:CreateInvalidation` on distribution `E34WTTE9HV683E`
- **One fresh TF-created access key** via `aws_iam_access_key` (NOT imported — secret
  was lost). Secret exposed via a `sensitive` output. The old key
  `AKIA2UC3A2NZ3WOIMLGE` (2026-02-22) is deleted as a documented post-apply step once
  the guide deploy is updated with the new credentials. (IAM allows 2 keys/user, so
  old + new coexist until cleanup.)

### `ses.tf` (matches the rentivo convention: manage identities, output tokens, DNS stays manual)

- `aws_ses_domain_identity` `eic-seminarios.com`
- `aws_ses_domain_dkim` for it (3 existing tokens)
- `aws_ses_domain_mail_from` → `ses.eic-seminarios.com`, `behavior_on_mx_failure = "UseDefaultValue"`
- `aws_ses_email_identity` `no-reply@eic-seminarios.com`
- Outputs: verification token, DKIM tokens (informational; DNS records already exist
  in Cloudflare and remain manually managed, exactly like rentivo).
- **Not managed:** the `my-first-configuration-set` default association. v1 SES
  resources do not track configuration-set association, so it causes no plan drift; it
  stays externally managed.

### `cloudfront.tf` (+ ACM, fully managed incl. Cloudflare validation)

- `aws_acm_certificate` `guide` — domain `guide.eic-seminarios.com`, `validation_method = "DNS"`.
  Imported (already ISSUED).
- `cloudflare_dns_record` for the ACM validation CNAME, imported from the existing
  Cloudflare record:
  - name `_96edaf591a8248fcdf34a050fe98e34c.guide.eic-seminarios.com`
  - value `_22162c9f330487ff0020c1cd040af1da.jkddzztszm.acm-validations.aws`
  - type `CNAME`, unproxied
  - Requires the existing Cloudflare record ID (looked up at implementation time with
    the CF API token).
- `aws_acm_certificate_validation` `guide` — references the cert ARN and the validation
  record FQDN. (No-op for an already-issued cert; included so the dependency graph is
  complete and re-validation works if the cert is ever recreated.)
- `aws_cloudfront_distribution` `E34WTTE9HV683E`, modeled exactly:
  - `enabled = true`, `is_ipv6_enabled = true`, `http_version = "http2"`, `price_class = "PriceClass_All"`
  - `aliases = ["guide.eic-seminarios.com"]`, `default_root_object = "index.html"`
  - comment `"CEFET-RJ Seminarios Guide Documentation"`
  - origin `S3-guide` → `guide.eic-seminarios.com.s3-website-us-east-1.amazonaws.com`,
    `custom_origin_config` (http-only, ports 80/443, TLSv1/1.1/1.2, 30s read / 5s keepalive)
  - default cache behavior: target `S3-guide`, `viewer_protocol_policy = "redirect-to-https"`,
    allowed/cached methods `[GET, HEAD]`, `compress = true`, legacy `forwarded_values`
    (query string off, cookies none), min/default/max TTL `0/3600/86400`
  - custom error response: 404 → `/index.html`, response code 200, min TTL 300
  - viewer certificate: ACM cert ARN, `ssl_support_method = "sni-only"`,
    `minimum_protocol_version = "TLSv1.2_2021"`
  - `restrictions { geo_restriction { restriction_type = "none" } }`
  - `depends_on`/cert reference via `aws_acm_certificate_validation.guide.certificate_arn`

## Import block inventory

| Address | ID |
|---|---|
| `aws_s3_bucket.eic_seminarios` | `eic-seminarios` |
| `aws_s3_bucket.guide` | `guide.eic-seminarios.com` |
| (+ each S3 sub-resource: id = bucket name) | |
| `aws_iam_user.eic_seminarios` | `eic-seminarios` |
| `aws_iam_policy.eic_seminarios_ses` | `arn:aws:iam::730335335283:policy/eic-seminarios-ses` |
| `aws_iam_user_policy_attachment.eic_seminarios_ses` | `eic-seminarios/arn:aws:iam::730335335283:policy/eic-seminarios-ses` |
| `aws_iam_access_key.eic_seminarios["2026"]` | `AKIA2UC3A2NZQRMLBG3Q` |
| `aws_iam_access_key.eic_seminarios["2024"]` | `AKIA2UC3A2NZTNO5HVHT` |
| `aws_iam_user.guide_uploader` | `eic-seminarios-guide-uploader` |
| `aws_iam_user_policy.guide_sync` | `eic-seminarios-guide-uploader:S3GuideSync` |
| `aws_ses_domain_identity.eic_seminarios` | `eic-seminarios.com` |
| `aws_ses_domain_dkim.eic_seminarios` | `eic-seminarios.com` |
| `aws_ses_domain_mail_from.eic_seminarios` | `eic-seminarios.com` |
| `aws_ses_email_identity.no_reply` | `no-reply@eic-seminarios.com` |
| `aws_acm_certificate.guide` | `arn:aws:acm:us-east-1:730335335283:certificate/b36e7001-bbd0-443f-8acb-c84eadc0973b` |
| `cloudflare_dns_record.acm_guide_validation` | `<zone_id>/<record_id>` (looked up) |
| `aws_cloudfront_distribution.guide` | `E34WTTE9HV683E` |

(`aws_iam_access_key` for the guide uploader is **created**, not imported.)

## Out of scope / follow-ups

- Delete old guide-uploader key `AKIA2UC3A2NZ3WOIMLGE` after the guide deploy is
  updated with the new TF-managed key.
- Optional prune of the 2024 main key `AKIA2UC3A2NZTNO5HVHT` if confirmed unused.
- SES `my-first-configuration-set` remains externally managed.
- SES/DKIM/MAIL-FROM DNS records remain manually managed in Cloudflare (matches rentivo).

## Verification

1. `terraform init` (downloads aws provider for the new alias).
2. `terraform plan` → expect imports + **0 changes**. Iterate config until clean.
3. `terraform validate` + `tflint` + pre-commit hooks pass.
4. Merge → CI `apply` performs the imports and creates the one new guide-uploader key.
5. Post-apply: retrieve new guide key from state output, update guide deploy, delete old key.
