variable "aws_region" {
  description = "AWS region for all resources in this configuration."
  type        = string
  default     = "us-east-1"
}

variable "server_ipv4" {
  description = "IPv4 of the shared upstream server proxied by Cloudflare for A records. Sourced from TF_VAR_server_ipv4 in CI."
  type        = string
}

variable "server_ipv6" {
  description = "IPv6 of the shared upstream server proxied by Cloudflare for AAAA records. Sourced from TF_VAR_server_ipv6 in CI."
  type        = string
}
