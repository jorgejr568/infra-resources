resource "aws_iam_user" "organizze_mcp_deployer" {
  name = "organizze-mcp-deployer"
  path = "/service/"
}

data "aws_iam_policy_document" "organizze_mcp_deploy" {
  statement {
    sid    = "ReadLambda"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionUrlConfig",
      "lambda:ListVersionsByFunction",
    ]
    resources = [
      aws_lambda_function.organizze_mcp_stats_ingest.arn,
      "${aws_lambda_function.organizze_mcp_stats_ingest.arn}:*",
    ]
  }

  statement {
    sid    = "DeployLambdaCode"
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
    ]
    resources = [aws_lambda_function.organizze_mcp_stats_ingest.arn]
  }

  statement {
    sid    = "ReadIngestSharedSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.organizze_mcp_ingest_shared_secret.arn]
  }
}

resource "aws_iam_policy" "organizze_mcp_deploy" {
  name        = "organizze-mcp-deploy"
  description = "Allows the organizze-mcp deployer user to push code to the stats ingest Lambda and read the ingest shared secret for baking into publisher builds."
  policy      = data.aws_iam_policy_document.organizze_mcp_deploy.json
}

resource "aws_iam_user_policy_attachment" "organizze_mcp_deploy" {
  user       = aws_iam_user.organizze_mcp_deployer.name
  policy_arn = aws_iam_policy.organizze_mcp_deploy.arn
}

resource "aws_iam_access_key" "organizze_mcp_deployer" {
  user = aws_iam_user.organizze_mcp_deployer.name
}

resource "aws_iam_user" "organizze_mcp_consumer" {
  name = "organizze-mcp-consumer"
  path = "/service/"
}

data "aws_iam_policy_document" "organizze_mcp_consume" {
  statement {
    sid    = "ConsumeOrganizzeMcpStatsQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:ChangeMessageVisibility",
      "sqs:ChangeMessageVisibilityBatch",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [
      aws_sqs_queue.organizze_mcp_stats.arn,
      aws_sqs_queue.organizze_mcp_stats_dlq.arn,
    ]
  }
}

resource "aws_iam_policy" "organizze_mcp_consume" {
  name        = "organizze-mcp-consume"
  description = "Allows the organizze-mcp consumer user to receive and delete messages from the stats queue and DLQ."
  policy      = data.aws_iam_policy_document.organizze_mcp_consume.json
}

resource "aws_iam_user_policy_attachment" "organizze_mcp_consume" {
  user       = aws_iam_user.organizze_mcp_consumer.name
  policy_arn = aws_iam_policy.organizze_mcp_consume.arn
}

resource "aws_iam_access_key" "organizze_mcp_consumer" {
  user = aws_iam_user.organizze_mcp_consumer.name
}

output "organizze_mcp_deployer_user_name" {
  description = "IAM user name for the organizze-mcp deployer."
  value       = aws_iam_user.organizze_mcp_deployer.name
}

output "organizze_mcp_deployer_access_key_id" {
  description = "Access key ID for the organizze-mcp deployer user."
  value       = aws_iam_access_key.organizze_mcp_deployer.id
  sensitive   = true
}

output "organizze_mcp_deployer_secret_access_key" {
  description = "Secret access key for the organizze-mcp deployer user."
  value       = aws_iam_access_key.organizze_mcp_deployer.secret
  sensitive   = true
}

output "organizze_mcp_consumer_user_name" {
  description = "IAM user name for the organizze-mcp consumer."
  value       = aws_iam_user.organizze_mcp_consumer.name
}

output "organizze_mcp_consumer_access_key_id" {
  description = "Access key ID for the organizze-mcp consumer user."
  value       = aws_iam_access_key.organizze_mcp_consumer.id
  sensitive   = true
}

output "organizze_mcp_consumer_secret_access_key" {
  description = "Secret access key for the organizze-mcp consumer user."
  value       = aws_iam_access_key.organizze_mcp_consumer.secret
  sensitive   = true
}
