data "cloudflare_zone" "joy_living" {
  name = "joyliving.com.br"
}

locals {
  joy_living_proxied_subdomains = toset(["@", "www", "api"])
}

resource "cloudflare_record" "joy_living_a" {
  for_each = local.joy_living_proxied_subdomains

  zone_id = data.cloudflare_zone.joy_living.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "joy_living_aaaa" {
  for_each = local.joy_living_proxied_subdomains

  zone_id = data.cloudflare_zone.joy_living.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

output "joy_living_zone_id" {
  description = "Cloudflare zone ID for joyliving.com.br."
  value       = data.cloudflare_zone.joy_living.id
}
