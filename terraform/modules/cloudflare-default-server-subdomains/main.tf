moved {
  from = cloudflare_record.a
  to   = cloudflare_dns_record.a
}

moved {
  from = cloudflare_record.aaaa
  to   = cloudflare_dns_record.aaaa
}

resource "cloudflare_dns_record" "a" {
  for_each = var.subdomains

  zone_id = var.zone_id
  name    = each.value
  type    = "A"
  ttl     = 1
  content = var.ipv4
  proxied = var.proxied
  comment = var.comment
}

resource "cloudflare_dns_record" "aaaa" {
  for_each = var.subdomains

  zone_id = var.zone_id
  name    = each.value
  type    = "AAAA"
  ttl     = 1
  content = var.ipv6
  proxied = var.proxied
  comment = var.comment
}
