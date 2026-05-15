resource "random_password" "organizze_mcp_ingest_shared_secret" {
  length  = 48
  special = false # URL-safe; goes in an HTTP header
}

resource "aws_secretsmanager_secret" "organizze_mcp_ingest_shared_secret" {
  name        = "organizze-mcp/ingest-shared-secret"
  description = "Shared secret the organizze-mcp ingest Lambda compares against the X-Ingest-Token header."
}

resource "aws_secretsmanager_secret_version" "organizze_mcp_ingest_shared_secret" {
  secret_id     = aws_secretsmanager_secret.organizze_mcp_ingest_shared_secret.id
  secret_string = random_password.organizze_mcp_ingest_shared_secret.result
}

output "organizze_mcp_ingest_shared_secret_arn" {
  description = "ARN of the organizze-mcp ingest shared-secret in Secrets Manager."
  value       = aws_secretsmanager_secret.organizze_mcp_ingest_shared_secret.arn
}

output "organizze_mcp_ingest_shared_secret_name" {
  description = "Name of the organizze-mcp ingest shared-secret in Secrets Manager."
  value       = aws_secretsmanager_secret.organizze_mcp_ingest_shared_secret.name
}
