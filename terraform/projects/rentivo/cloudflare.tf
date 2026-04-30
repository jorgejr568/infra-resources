data "cloudflare_zone" "rentivo" {
  name = local.rentivo_domain
}

locals {
  rentivo_proxied_subdomains = toset(["@", "www"])
}

resource "cloudflare_record" "rentivo_a" {
  for_each = local.rentivo_proxied_subdomains

  zone_id = data.cloudflare_zone.rentivo.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_aaaa" {
  for_each = local.rentivo_proxied_subdomains

  zone_id = data.cloudflare_zone.rentivo.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_dmarc" {
  zone_id = data.cloudflare_zone.rentivo.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=none;"
  comment = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.rentivo.dkim_tokens)

  zone_id = data.cloudflare_zone.rentivo.id
  name    = "${each.value}._domainkey"
  type    = "CNAME"
  content = "${each.value}.dkim.amazonses.com"
  proxied = false
  comment = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_mail_mx" {
  zone_id  = data.cloudflare_zone.rentivo.id
  name     = "mail"
  type     = "MX"
  content  = "feedback-smtp.us-east-1.amazonses.com"
  priority = 10
  comment  = "Terraform managed record"
}

resource "cloudflare_record" "rentivo_mail_spf" {
  zone_id = data.cloudflare_zone.rentivo.id
  name    = "mail"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  comment = "Terraform managed record"
}

output "rentivo_zone_id" {
  description = "Cloudflare zone ID for rentivo.com.br."
  value       = data.cloudflare_zone.rentivo.id
}
