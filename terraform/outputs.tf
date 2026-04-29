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
