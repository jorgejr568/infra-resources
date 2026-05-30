resource "cloudflare_turnstile_widget" "portfolio" {
  account_id = var.cloudflare_account_id
  name       = "jorgejunior.dev portfolio"
  # Ordered to match the order Cloudflare's API returns (alphabetical), so plans
  # don't perpetually show a no-op reordering diff.
  domains = ["jorgejunior.dev", "me.jorgejunior.dev", "www.jorgejunior.dev"]
  mode    = "managed"
  region  = "world"
}

output "jorgejunior_portfolio_turnstile_sitekey" {
  description = "Cloudflare Turnstile sitekey for the jorgejunior.dev portfolio (embed in HTML)."
  value       = cloudflare_turnstile_widget.portfolio.sitekey
}

output "jorgejunior_portfolio_turnstile_secret" {
  description = "Cloudflare Turnstile secret for the jorgejunior.dev portfolio (used by the verification endpoint)."
  value       = cloudflare_turnstile_widget.portfolio.secret
  sensitive   = true
}
