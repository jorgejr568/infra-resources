data "cloudflare_zone" "eic_seminarios" {
  name = "eic-seminarios.com"
}

module "cf_proxied_eic_seminarios" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.eic_seminarios.id
  subdomains = toset(["beta", "mail-beta", "console-s3-beta"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.eic_seminarios_a
  to   = module.cf_proxied_eic_seminarios.cloudflare_record.a
}

moved {
  from = cloudflare_record.eic_seminarios_aaaa
  to   = module.cf_proxied_eic_seminarios.cloudflare_record.aaaa
}

module "cf_unproxied_eic_seminarios" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.eic_seminarios.id
  subdomains = toset(["s3-beta"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
  proxied    = false
  comment    = "Terraform managed record (DNS-only: MinIO S3 API needs unproxied for SigV4)"
}

moved {
  from = cloudflare_record.eic_seminarios_a_unproxied
  to   = module.cf_unproxied_eic_seminarios.cloudflare_record.a
}

moved {
  from = cloudflare_record.eic_seminarios_aaaa_unproxied
  to   = module.cf_unproxied_eic_seminarios.cloudflare_record.aaaa
}

output "eic_seminarios_zone_id" {
  description = "Cloudflare zone ID for eic-seminarios.com."
  value       = data.cloudflare_zone.eic_seminarios.id
}
