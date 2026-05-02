data "cloudflare_zone" "rentivo" {
  filter = {
    name = local.rentivo_domain
  }
}

module "cf_proxied_rentivo" {
  source = "../../modules/cloudflare-default-server-subdomains"

  zone_id    = data.cloudflare_zone.rentivo.id
  subdomains = toset(["@", "www"])
  ipv4       = var.server_ipv4
  ipv6       = var.server_ipv6
}

moved {
  from = cloudflare_record.rentivo_dmarc
  to   = cloudflare_dns_record.rentivo_dmarc
}

moved {
  from = cloudflare_record.rentivo_ses_dkim
  to   = cloudflare_dns_record.rentivo_ses_dkim
}

moved {
  from = cloudflare_record.rentivo_mail_mx
  to   = cloudflare_dns_record.rentivo_mail_mx
}

moved {
  from = cloudflare_record.rentivo_mail_spf
  to   = cloudflare_dns_record.rentivo_mail_spf
}

resource "cloudflare_dns_record" "rentivo_dmarc" {
  zone_id = data.cloudflare_zone.rentivo.id
  name    = "_dmarc"
  type    = "TXT"
  ttl     = 1
  content = "v=DMARC1; p=none;"
  comment = "Terraform managed record"
}

resource "cloudflare_dns_record" "rentivo_ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.rentivo.dkim_tokens)

  zone_id = data.cloudflare_zone.rentivo.id
  name    = "${each.value}._domainkey"
  type    = "CNAME"
  ttl     = 1
  content = "${each.value}.dkim.amazonses.com"
  proxied = false
  comment = "Terraform managed record"
}

resource "cloudflare_dns_record" "rentivo_mail_mx" {
  zone_id  = data.cloudflare_zone.rentivo.id
  name     = "mail"
  type     = "MX"
  ttl      = 1
  content  = "feedback-smtp.us-east-1.amazonses.com"
  priority = 10
  comment  = "Terraform managed record"
}

resource "cloudflare_dns_record" "rentivo_mail_spf" {
  zone_id = data.cloudflare_zone.rentivo.id
  name    = "mail"
  type    = "TXT"
  ttl     = 1
  content = "v=spf1 include:amazonses.com ~all"
  comment = "Terraform managed record"
}

output "rentivo_zone_id" {
  description = "Cloudflare zone ID for rentivo.com.br."
  value       = data.cloudflare_zone.rentivo.id
}
