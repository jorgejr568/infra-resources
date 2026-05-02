variable "zone_id" {
  description = "Cloudflare zone ID that owns the records."
  type        = string
}

variable "subdomains" {
  description = "Set of subdomain names (e.g. [\"@\", \"www\"]) to create A and AAAA records for."
  type        = set(string)
}

variable "ipv4" {
  description = "Origin IPv4 address used as the A record content."
  type        = string
}

variable "ipv6" {
  description = "Origin IPv6 address used as the AAAA record content."
  type        = string
}

variable "proxied" {
  description = "Whether the records should be proxied through Cloudflare."
  type        = bool
  default     = true
}

variable "comment" {
  description = "Comment attached to each emitted record."
  type        = string
  default     = "Terraform managed record"
}
