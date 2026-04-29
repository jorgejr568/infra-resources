output "hooks_fyi_request_files_bucket" {
  description = "Name of the request-files S3 bucket."
  value       = module.hooks_fyi.hooks_fyi_request_files_bucket
}

output "hooks_fyi_request_files_bucket_arn" {
  description = "ARN of the request-files S3 bucket."
  value       = module.hooks_fyi.hooks_fyi_request_files_bucket_arn
}

output "hooks_fyi_user_name" {
  description = "IAM user name for the hooks-fyi service account."
  value       = module.hooks_fyi.hooks_fyi_user_name
}

output "hooks_fyi_access_key_id" {
  description = "Access key ID for the hooks-fyi user."
  value       = module.hooks_fyi.hooks_fyi_access_key_id
  sensitive   = true
}

output "hooks_fyi_secret_access_key" {
  description = "Secret access key for the hooks-fyi user."
  value       = module.hooks_fyi.hooks_fyi_secret_access_key
  sensitive   = true
}

output "rentivo_files_bucket" {
  description = "Name of the rentivo-files S3 bucket."
  value       = module.rentivo.rentivo_files_bucket
}

output "rentivo_files_bucket_arn" {
  description = "ARN of the rentivo-files S3 bucket."
  value       = module.rentivo.rentivo_files_bucket_arn
}

output "rentivo_user_name" {
  description = "IAM user name for the rentivo service account."
  value       = module.rentivo.rentivo_user_name
}

output "rentivo_access_key_id" {
  description = "Access key ID for the rentivo user."
  value       = module.rentivo.rentivo_access_key_id
  sensitive   = true
}

output "rentivo_secret_access_key" {
  description = "Secret access key for the rentivo user."
  value       = module.rentivo.rentivo_secret_access_key
  sensitive   = true
}

output "rentivo_ses_domain" {
  description = "SES domain identity for Rentivo."
  value       = module.rentivo.rentivo_ses_domain
}

output "rentivo_ses_verification_token" {
  description = "SES domain verification token (TXT record value for _amazonses.rentivo.com.br)."
  value       = module.rentivo.rentivo_ses_verification_token
}

output "rentivo_ses_dkim_tokens" {
  description = "SES DKIM tokens (publish three CNAMEs: <token>._domainkey.rentivo.com.br -> <token>.dkim.amazonses.com)."
  value       = module.rentivo.rentivo_ses_dkim_tokens
}
