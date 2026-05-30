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

output "hooks_fyi_zone_id" {
  description = "Cloudflare zone ID for hooks.fyi."
  value       = module.hooks_fyi.hooks_fyi_zone_id
}

output "rentivo_zone_id" {
  description = "Cloudflare zone ID for rentivo.com.br."
  value       = module.rentivo.rentivo_zone_id
}

output "jorgejunior_dev_zone_id" {
  description = "Cloudflare zone ID for jorgejunior.dev."
  value       = module.jorgejunior.jorgejunior_dev_zone_id
}

output "j_jr_app_zone_id" {
  description = "Cloudflare zone ID for j-jr.app."
  value       = module.jorgejunior.j_jr_app_zone_id
}

output "jorgejunior_portfolio_turnstile_sitekey" {
  description = "Cloudflare Turnstile sitekey for the jorgejunior.dev portfolio (embed in HTML)."
  value       = module.jorgejunior.jorgejunior_portfolio_turnstile_sitekey
}

output "jorgejunior_portfolio_turnstile_secret" {
  description = "Cloudflare Turnstile secret for the jorgejunior.dev portfolio (used by the verification endpoint)."
  value       = module.jorgejunior.jorgejunior_portfolio_turnstile_secret
  sensitive   = true
}

output "eic_seminarios_zone_id" {
  description = "Cloudflare zone ID for eic-seminarios.com."
  value       = module.eic_seminarios.eic_seminarios_zone_id
}

output "eic_seminarios_bucket" {
  description = "Name of the private eic-seminarios application bucket."
  value       = module.eic_seminarios.eic_seminarios_bucket
}

output "eic_seminarios_guide_bucket" {
  description = "Name of the public guide static-website bucket."
  value       = module.eic_seminarios.guide_bucket
}

output "eic_seminarios_guide_distribution_id" {
  description = "CloudFront distribution ID serving guide.eic-seminarios.com."
  value       = module.eic_seminarios.guide_distribution_id
}

output "eic_seminarios_dkim_tokens" {
  description = "SES DKIM tokens for eic-seminarios.com (publish three CNAMEs: <token>._domainkey.eic-seminarios.com -> <token>.dkim.amazonses.com)."
  value       = module.eic_seminarios.eic_seminarios_dkim_tokens
}

output "eic_seminarios_guide_uploader_access_key_id" {
  description = "Access key ID for the eic-seminarios guide-uploader user."
  value       = module.eic_seminarios.guide_uploader_access_key_id
  sensitive   = true
}

output "eic_seminarios_guide_uploader_secret_access_key" {
  description = "Secret access key for the eic-seminarios guide-uploader user."
  value       = module.eic_seminarios.guide_uploader_secret_access_key
  sensitive   = true
}

output "joy_living_zone_id" {
  description = "Cloudflare zone ID for joyliving.com.br."
  value       = module.joy_living.joy_living_zone_id
}

output "rentivo_kms_key_id" {
  description = "ID of the rentivo KMS key."
  value       = module.rentivo.rentivo_kms_key_id
}

output "rentivo_kms_key_arn" {
  description = "ARN of the rentivo KMS key."
  value       = module.rentivo.rentivo_kms_key_arn
}

output "rentivo_kms_alias" {
  description = "Alias of the rentivo KMS key."
  value       = module.rentivo.rentivo_kms_alias
}

output "organizze_mcp_stats_queue_name" {
  description = "Name of the organizze-mcp stats SQS queue."
  value       = module.organizze_mcp.organizze_mcp_stats_queue_name
}

output "organizze_mcp_stats_queue_url" {
  description = "URL of the organizze-mcp stats SQS queue."
  value       = module.organizze_mcp.organizze_mcp_stats_queue_url
}

output "organizze_mcp_stats_queue_arn" {
  description = "ARN of the organizze-mcp stats SQS queue."
  value       = module.organizze_mcp.organizze_mcp_stats_queue_arn
}

output "organizze_mcp_stats_dlq_name" {
  description = "Name of the organizze-mcp stats DLQ."
  value       = module.organizze_mcp.organizze_mcp_stats_dlq_name
}

output "organizze_mcp_stats_dlq_url" {
  description = "URL of the organizze-mcp stats DLQ."
  value       = module.organizze_mcp.organizze_mcp_stats_dlq_url
}

output "organizze_mcp_stats_dlq_arn" {
  description = "ARN of the organizze-mcp stats DLQ."
  value       = module.organizze_mcp.organizze_mcp_stats_dlq_arn
}

output "organizze_mcp_stats_ingest_function_name" {
  description = "Name of the organizze-mcp stats ingest Lambda function."
  value       = module.organizze_mcp.organizze_mcp_stats_ingest_function_name
}

output "organizze_mcp_stats_ingest_function_arn" {
  description = "ARN of the organizze-mcp stats ingest Lambda function."
  value       = module.organizze_mcp.organizze_mcp_stats_ingest_function_arn
}

output "organizze_mcp_stats_ingest_function_url" {
  description = "Public HTTPS URL of the organizze-mcp stats ingest Lambda."
  value       = module.organizze_mcp.organizze_mcp_stats_ingest_function_url
}

output "organizze_mcp_lambda_exec_role_arn" {
  description = "ARN of the organizze-mcp Lambda execution role."
  value       = module.organizze_mcp.organizze_mcp_lambda_exec_role_arn
}

output "organizze_mcp_ingest_shared_secret_arn" {
  description = "ARN of the organizze-mcp ingest shared-secret in Secrets Manager."
  value       = module.organizze_mcp.organizze_mcp_ingest_shared_secret_arn
}

output "organizze_mcp_ingest_shared_secret_name" {
  description = "Name of the organizze-mcp ingest shared-secret in Secrets Manager."
  value       = module.organizze_mcp.organizze_mcp_ingest_shared_secret_name
}

output "organizze_mcp_deployer_user_name" {
  description = "IAM user name for the organizze-mcp deployer."
  value       = module.organizze_mcp.organizze_mcp_deployer_user_name
}

output "organizze_mcp_deployer_access_key_id" {
  description = "Access key ID for the organizze-mcp deployer user."
  value       = module.organizze_mcp.organizze_mcp_deployer_access_key_id
  sensitive   = true
}

output "organizze_mcp_deployer_secret_access_key" {
  description = "Secret access key for the organizze-mcp deployer user."
  value       = module.organizze_mcp.organizze_mcp_deployer_secret_access_key
  sensitive   = true
}

output "organizze_mcp_consumer_user_name" {
  description = "IAM user name for the organizze-mcp consumer."
  value       = module.organizze_mcp.organizze_mcp_consumer_user_name
}

output "organizze_mcp_consumer_access_key_id" {
  description = "Access key ID for the organizze-mcp consumer user."
  value       = module.organizze_mcp.organizze_mcp_consumer_access_key_id
  sensitive   = true
}

output "organizze_mcp_consumer_secret_access_key" {
  description = "Secret access key for the organizze-mcp consumer user."
  value       = module.organizze_mcp.organizze_mcp_consumer_secret_access_key
  sensitive   = true
}
