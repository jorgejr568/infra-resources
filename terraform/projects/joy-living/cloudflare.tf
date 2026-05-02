data "cloudflare_zone" "joy_living" {
  filter = {
    name = "joyliving.com.br"
  }
}

module "cf_proxied_joy_living" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.joy_living.id
  subdomains = toset(["@", "www", "api"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

output "joy_living_zone_id" {
  description = "Cloudflare zone ID for joyliving.com.br."
  value       = data.cloudflare_zone.joy_living.id
}
