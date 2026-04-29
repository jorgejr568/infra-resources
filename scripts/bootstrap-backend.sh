#!/usr/bin/env bash
# Creates the S3 bucket and DynamoDB lock table used as the Terraform remote
# state backend for this repo. Run once per AWS account, before the first
# `terraform apply`.
#
# Usage:
#   AWS_PROFILE=hooks-fyi ./scripts/bootstrap-backend.sh
#
# Idempotent: re-running is safe; existing resources are left alone.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET="${STATE_BUCKET:-aws-resources-tfstate}"
LOCK_TABLE="${LOCK_TABLE:-aws-resources-tflock}"

echo "Region:       $REGION"
echo "State bucket: $STATE_BUCKET"
echo "Lock table:   $LOCK_TABLE"
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

# --- DynamoDB lock table -----------------------------------------------------
if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "✓ Lock table $LOCK_TABLE already exists."
else
  echo "→ Creating lock table $LOCK_TABLE ..."
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --region "$REGION" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
  aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$REGION"
fi

echo
echo "✓ Backend ready. You can now run terraform from CI or locally."
