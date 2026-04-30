data "cloudflare_zone" "hooks_fyi" {
  name = "hooks.fyi"
}

locals {
  hooks_fyi_proxied_subdomains = toset(["@", "www"])
}

resource "cloudflare_record" "hooks_fyi_a" {
  for_each = local.hooks_fyi_proxied_subdomains

  zone_id = data.cloudflare_zone.hooks_fyi.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "hooks_fyi_aaaa" {
  for_each = local.hooks_fyi_proxied_subdomains

  zone_id = data.cloudflare_zone.hooks_fyi.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

output "hooks_fyi_zone_id" {
  description = "Cloudflare zone ID for hooks.fyi."
  value       = data.cloudflare_zone.hooks_fyi.id
}
