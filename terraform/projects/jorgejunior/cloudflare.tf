data "cloudflare_zone" "jorgejunior_dev" {
  name = "jorgejunior.dev"
}

data "cloudflare_zone" "j_jr_app" {
  name = "j-jr.app"
}

locals {
  vercel_cname_target = "cname.vercel-dns.com"

  jorgejunior_dev_proxied_subdomains = toset([
    "www", "@",
    "wheregoes",
    "api",
    "dns",
    "estimates",
    "exchange-register",
    "me",
    "meta",
    "nova",
    "pdf",
    "s3", "s3-manager",
    "flux",
    "vscode",
    "land",
  ])

  j_jr_app_proxied_subdomains = toset([
    "@", "www",
    "panela-magica-api", "tourquest",
    "wheregoes-api", "wheregoes",
    "yt",
    "flux",
  ])

  j_jr_app_vercel_subdomains = toset([
    "worktrackr",
    "panela-magica",
  ])

  jorgejunior_dev_mx_records = {
    bounces_ses = {
      name     = "bounces"
      content  = "feedback-smtp.sa-east-1.amazonses.com"
      priority = 10
    }
    mg_mailgun_a = {
      name     = "mg"
      content  = "mxa.mailgun.org"
      priority = 10
    }
    mg_mailgun_b = {
      name     = "mg"
      content  = "mxb.mailgun.org"
      priority = 20
    }
  }
}

resource "cloudflare_record" "jorgejunior_dev_a" {
  for_each = local.jorgejunior_dev_proxied_subdomains

  zone_id = data.cloudflare_zone.jorgejunior_dev.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "jorgejunior_dev_aaaa" {
  for_each = local.jorgejunior_dev_proxied_subdomains

  zone_id = data.cloudflare_zone.jorgejunior_dev.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "jorgejunior_dev_mx" {
  for_each = local.jorgejunior_dev_mx_records

  zone_id  = data.cloudflare_zone.jorgejunior_dev.id
  name     = each.value.name
  type     = "MX"
  content  = each.value.content
  priority = each.value.priority
  comment  = "Terraform managed record"
}

resource "cloudflare_record" "j_jr_app_a" {
  for_each = local.j_jr_app_proxied_subdomains

  zone_id = data.cloudflare_zone.j_jr_app.id
  name    = each.value
  type    = "A"
  content = var.server_ipv4
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "j_jr_app_aaaa" {
  for_each = local.j_jr_app_proxied_subdomains

  zone_id = data.cloudflare_zone.j_jr_app.id
  name    = each.value
  type    = "AAAA"
  content = var.server_ipv6
  proxied = true
  comment = "Terraform managed record"
}

resource "cloudflare_record" "j_jr_app_vercel" {
  for_each = local.j_jr_app_vercel_subdomains

  zone_id = data.cloudflare_zone.j_jr_app.id
  name    = each.value
  type    = "CNAME"
  content = local.vercel_cname_target
  proxied = false
  comment = "Terraform managed record"
}

output "jorgejunior_dev_zone_id" {
  description = "Cloudflare zone ID for jorgejunior.dev."
  value       = data.cloudflare_zone.jorgejunior_dev.id
}

output "j_jr_app_zone_id" {
  description = "Cloudflare zone ID for j-jr.app."
  value       = data.cloudflare_zone.j_jr_app.id
}
