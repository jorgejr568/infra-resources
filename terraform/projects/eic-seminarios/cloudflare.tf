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

module "cf_unproxied_eic_seminarios" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.eic_seminarios.id
  subdomains = toset(["s3-beta"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
  proxied    = false
  comment    = "Terraform managed record (DNS-only: MinIO S3 API needs unproxied for SigV4)"
}

output "eic_seminarios_zone_id" {
  description = "Cloudflare zone ID for eic-seminarios.com."
  value       = data.cloudflare_zone.eic_seminarios.id
}
