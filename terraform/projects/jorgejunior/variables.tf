variable "server_ipv4" {
  description = "Upstream server IPv4 for proxied A records."
  type        = string
}

variable "server_ipv6" {
  description = "Upstream server IPv6 for proxied AAAA records."
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for account-scoped resources (Turnstile)."
  type        = string
}
