data "archive_file" "organizze_mcp_stats_ingest_placeholder" {
  type        = "zip"
  output_path = "${path.module}/.placeholder.zip"

  source {
    content  = "#!/bin/sh\necho 'placeholder bootstrap — deploy real Go binary via the organizze-mcp-deployer user' >&2\nexit 1\n"
    filename = "bootstrap"
  }
}

data "aws_iam_policy_document" "organizze_mcp_lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "organizze_mcp_lambda_exec" {
  name               = "organizze-mcp-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.organizze_mcp_lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "organizze_mcp_lambda_basic" {
  role       = aws_iam_role.organizze_mcp_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "organizze_mcp_lambda_sqs_send" {
  statement {
    sid    = "SendToOrganizzeMcpStatsQueue"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:SendMessageBatch",
      "sqs:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.organizze_mcp_stats.arn]
  }
}

resource "aws_iam_policy" "organizze_mcp_lambda_sqs_send" {
  name        = "organizze-mcp-lambda-sqs-send"
  description = "Allows the organizze-mcp ingest lambda to send messages to the stats queue."
  policy      = data.aws_iam_policy_document.organizze_mcp_lambda_sqs_send.json
}

resource "aws_iam_role_policy_attachment" "organizze_mcp_lambda_sqs_send" {
  role       = aws_iam_role.organizze_mcp_lambda_exec.name
  policy_arn = aws_iam_policy.organizze_mcp_lambda_sqs_send.arn
}

data "aws_iam_policy_document" "organizze_mcp_lambda_read_ingest_secret" {
  statement {
    sid    = "ReadOrganizzeMcpIngestSharedSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.organizze_mcp_ingest_shared_secret.arn]
  }
}

resource "aws_iam_policy" "organizze_mcp_lambda_read_ingest_secret" {
  name        = "organizze-mcp-lambda-read-ingest-secret"
  description = "Allows the organizze-mcp ingest lambda to read its shared secret from Secrets Manager."
  policy      = data.aws_iam_policy_document.organizze_mcp_lambda_read_ingest_secret.json
}

resource "aws_iam_role_policy_attachment" "organizze_mcp_lambda_read_ingest_secret" {
  role       = aws_iam_role.organizze_mcp_lambda_exec.name
  policy_arn = aws_iam_policy.organizze_mcp_lambda_read_ingest_secret.arn
}

resource "aws_cloudwatch_log_group" "organizze_mcp_stats_ingest" {
  name              = "/aws/lambda/organizze-mcp-stats-ingest"
  retention_in_days = 30
}

resource "aws_lambda_function" "organizze_mcp_stats_ingest" {
  function_name = "organizze-mcp-stats-ingest"
  role          = aws_iam_role.organizze_mcp_lambda_exec.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  memory_size   = 128
  timeout       = 10

  filename         = data.archive_file.organizze_mcp_stats_ingest_placeholder.output_path
  source_code_hash = data.archive_file.organizze_mcp_stats_ingest_placeholder.output_base64sha256

  environment {
    variables = {
      STATS_QUEUE_URL          = aws_sqs_queue.organizze_mcp_stats.url
      INGEST_SHARED_SECRET_ARN = aws_secretsmanager_secret.organizze_mcp_ingest_shared_secret.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.organizze_mcp_stats_ingest,
    aws_iam_role_policy_attachment.organizze_mcp_lambda_basic,
    aws_iam_role_policy_attachment.organizze_mcp_lambda_read_ingest_secret,
  ]

  # Code is deployed out-of-band by the organizze-mcp-deployer user via
  # `aws lambda update-function-code`; ignore so Terraform doesn't reset it.
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

resource "aws_lambda_function_url" "organizze_mcp_stats_ingest" {
  function_name      = aws_lambda_function.organizze_mcp_stats_ingest.function_name
  authorization_type = "NONE"
}

output "organizze_mcp_stats_ingest_function_name" {
  description = "Name of the organizze-mcp stats ingest Lambda function."
  value       = aws_lambda_function.organizze_mcp_stats_ingest.function_name
}

output "organizze_mcp_stats_ingest_function_arn" {
  description = "ARN of the organizze-mcp stats ingest Lambda function."
  value       = aws_lambda_function.organizze_mcp_stats_ingest.arn
}

output "organizze_mcp_stats_ingest_function_url" {
  description = "Public HTTPS URL of the organizze-mcp stats ingest Lambda."
  value       = aws_lambda_function_url.organizze_mcp_stats_ingest.function_url
}

output "organizze_mcp_lambda_exec_role_arn" {
  description = "ARN of the organizze-mcp Lambda execution role."
  value       = aws_iam_role.organizze_mcp_lambda_exec.arn
}
