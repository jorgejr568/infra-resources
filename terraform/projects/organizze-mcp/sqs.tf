resource "aws_sqs_queue" "organizze_mcp_stats_dlq" {
  name                      = "organizze-mcp-stats-dlq"
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "organizze_mcp_stats" {
  name                       = "organizze-mcp-stats"
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 30
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.organizze_mcp_stats_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "organizze_mcp_stats_dlq" {
  queue_url = aws_sqs_queue.organizze_mcp_stats_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.organizze_mcp_stats.arn]
  })
}

output "organizze_mcp_stats_queue_name" {
  description = "Name of the organizze-mcp stats SQS queue."
  value       = aws_sqs_queue.organizze_mcp_stats.name
}

output "organizze_mcp_stats_queue_url" {
  description = "URL of the organizze-mcp stats SQS queue."
  value       = aws_sqs_queue.organizze_mcp_stats.url
}

output "organizze_mcp_stats_queue_arn" {
  description = "ARN of the organizze-mcp stats SQS queue."
  value       = aws_sqs_queue.organizze_mcp_stats.arn
}

output "organizze_mcp_stats_dlq_name" {
  description = "Name of the organizze-mcp stats DLQ."
  value       = aws_sqs_queue.organizze_mcp_stats_dlq.name
}

output "organizze_mcp_stats_dlq_url" {
  description = "URL of the organizze-mcp stats DLQ."
  value       = aws_sqs_queue.organizze_mcp_stats_dlq.url
}

output "organizze_mcp_stats_dlq_arn" {
  description = "ARN of the organizze-mcp stats DLQ."
  value       = aws_sqs_queue.organizze_mcp_stats_dlq.arn
}
