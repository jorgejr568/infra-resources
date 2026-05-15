#!/usr/bin/env bash
# Creates the S3 bucket used as the Terraform remote state backend for this
# repo. Run once per AWS account, before the first `terraform apply`.
#
# Locking is handled by the S3 backend's native `use_lockfile = true` option
# (Terraform >= 1.10), which writes a sibling `.tflock` object — no separate
# DynamoDB table is required.
#
# Usage:
#   AWS_PROFILE=hooks-fyi ./scripts/bootstrap-backend.sh
#
# Idempotent: re-running is safe; existing resources are left alone.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET="${STATE_BUCKET:-jorgejr568-aws-resources-tfstate}"

echo "Region:       $REGION"
echo "State bucket: $STATE_BUCKET"
echo

# --- S3 bucket ---------------------------------------------------------------
if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  echo "✓ Bucket $STATE_BUCKET already exists."
else
  echo "→ Creating bucket $STATE_BUCKET ..."
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
fi

echo "→ Enabling versioning ..."
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

echo "→ Enabling default encryption (AES256) ..."
aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]
  }'

echo "→ Blocking all public access ..."
aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration '{
    "BlockPublicAcls":true,"IgnorePublicAcls":true,
    "BlockPublicPolicy":true,"RestrictPublicBuckets":true
  }'

echo
echo "✓ Backend ready. You can now run terraform from CI or locally."
