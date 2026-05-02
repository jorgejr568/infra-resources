data "cloudflare_zone" "hooks_fyi" {
  name = "hooks.fyi"
}

module "cf_proxied_hooks_fyi" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.hooks_fyi.id
  subdomains = toset(["@", "www"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.hooks_fyi_a
  to   = module.cf_proxied_hooks_fyi.cloudflare_record.a
}

moved {
  from = cloudflare_record.hooks_fyi_aaaa
  to   = module.cf_proxied_hooks_fyi.cloudflare_record.aaaa
}

output "hooks_fyi_zone_id" {
  description = "Cloudflare zone ID for hooks.fyi."
  value       = data.cloudflare_zone.hooks_fyi.id
}
