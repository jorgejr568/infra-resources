data "cloudflare_zone" "joy_living" {
  name = "joyliving.com.br"
}

module "cf_proxied_joy_living" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.joy_living.id
  subdomains = toset(["@", "www", "api"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.joy_living_a
  to   = module.cf_proxied_joy_living.cloudflare_record.a
}

moved {
  from = cloudflare_record.joy_living_aaaa
  to   = module.cf_proxied_joy_living.cloudflare_record.aaaa
}

output "joy_living_zone_id" {
  description = "Cloudflare zone ID for joyliving.com.br."
  value       = data.cloudflare_zone.joy_living.id
}
