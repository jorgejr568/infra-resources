data "cloudflare_zone" "eic_seminarios" {
  name = "eic-seminarios.com"
}

locals {
  eic_seminarios_proxied_subdomains = toset(["v2"])
}

resource "cloudflare_record" "eic_seminarios_a" {
  for_each = local.eic_seminarios_proxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "eic_seminarios_aaaa" {
  for_each = local.eic_seminarios_proxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

output "eic_seminarios_zone_id" {
  description = "Cloudflare zone ID for eic-seminarios.com."
  value       = data.cloudflare_zone.eic_seminarios.id
}
