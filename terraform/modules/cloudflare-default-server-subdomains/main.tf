resource "cloudflare_record" "a" {
  for_each = var.subdomains

  zone_id = var.zone_id
  name    = each.value
  type    = "A"
  content = var.ipv4
  proxied = var.proxied
  comment = var.comment
}

resource "cloudflare_record" "aaaa" {
  for_each = var.subdomains

  zone_id = var.zone_id
  name    = each.value
  type    = "AAAA"
  content = var.ipv6
  proxied = var.proxied
  comment = var.comment
}
