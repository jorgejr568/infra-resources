data "cloudflare_zone" "eic_seminarios" {
  name = "eic-seminarios.com"
}

locals {
  eic_seminarios_proxied_subdomains   = toset(["beta", "mail-beta", "console-s3-beta"])
  eic_seminarios_unproxied_subdomains = toset(["s3-beta"])
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

resource "cloudflare_record" "eic_seminarios_a_unproxied" {
  for_each = local.eic_seminarios_unproxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = false
  comment = "Terraform managed record (DNS-only: MinIO S3 API needs unproxied for SigV4)"
}

resource "cloudflare_record" "eic_seminarios_aaaa_unproxied" {
  for_each = local.eic_seminarios_unproxied_subdomains

  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = false
  comment = "Terraform managed record (DNS-only: MinIO S3 API needs unproxied for SigV4)"
}

output "eic_seminarios_zone_id" {
  description = "Cloudflare zone ID for eic-seminarios.com."
  value       = data.cloudflare_zone.eic_seminarios.id
}
