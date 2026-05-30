# Import blocks for adopting the existing eic-seminarios AWS resources.
# Import blocks must live in the root module and reference resources via the
# module path. Remove this file in a follow-up PR after the import apply succeeds.

import {
  to = module.eic_seminarios.aws_s3_bucket.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_versioning.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_server_side_encryption_configuration.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_public_access_block.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_ownership_controls.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_server_side_encryption_configuration.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_ownership_controls.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_public_access_block.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_website_configuration.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_policy.guide
  id = "guide.eic-seminarios.com"
}

import {
  to = module.eic_seminarios.aws_acm_certificate.guide
  id = "arn:aws:acm:us-east-1:730335335283:certificate/b36e7001-bbd0-443f-8acb-c84eadc0973b"
}
import {
  to = module.eic_seminarios.cloudflare_dns_record.acm_guide_validation
  id = "a0cad208e1aacc23ef78414b46d22cb9/deaf1e1a1a78b7bde7bde2a3478067f1"
}
import {
  to = module.eic_seminarios.aws_cloudfront_distribution.guide
  id = "E34WTTE9HV683E"
}

import {
  to = module.eic_seminarios.aws_sesv2_email_identity.eic_seminarios
  id = "eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_sesv2_email_identity_mail_from_attributes.eic_seminarios
  id = "eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_sesv2_email_identity.no_reply
  id = "no-reply@eic-seminarios.com"
}

import {
  to = module.eic_seminarios.aws_iam_user.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_iam_policy.eic_seminarios_ses
  id = "arn:aws:iam::730335335283:policy/eic-seminarios-ses"
}
import {
  to = module.eic_seminarios.aws_iam_user_policy_attachment.eic_seminarios_ses
  id = "eic-seminarios/arn:aws:iam::730335335283:policy/eic-seminarios-ses"
}
import {
  to = module.eic_seminarios.aws_iam_access_key.eic_seminarios["2026-01"]
  id = "AKIA2UC3A2NZQRMLBG3Q"
}
import {
  to = module.eic_seminarios.aws_iam_access_key.eic_seminarios["2024-10"]
  id = "AKIA2UC3A2NZTNO5HVHT"
}
import {
  to = module.eic_seminarios.aws_iam_user.guide_uploader
  id = "eic-seminarios-guide-uploader"
}
import {
  to = module.eic_seminarios.aws_iam_user_policy.guide_sync
  id = "eic-seminarios-guide-uploader:S3GuideSync"
}
