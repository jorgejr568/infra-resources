locals {
  rentivo_domain      = "rentivo.com.br"
  rentivo_from_sender = "naoresponder@${local.rentivo_domain}"
}

resource "aws_ses_domain_identity" "rentivo" {
  domain = local.rentivo_domain
}

resource "aws_ses_domain_dkim" "rentivo" {
  domain = aws_ses_domain_identity.rentivo.domain
}

output "rentivo_ses_domain" {
  description = "SES domain identity for Rentivo. Verify by adding the verification TXT and DKIM CNAMEs to DNS."
  value       = aws_ses_domain_identity.rentivo.domain
}

output "rentivo_ses_verification_token" {
  description = "SES domain verification token. Publish as TXT record at _amazonses.<domain>."
  value       = aws_ses_domain_identity.rentivo.verification_token
}

output "rentivo_ses_dkim_tokens" {
  description = "DKIM tokens. For each token <t>, publish a CNAME at <t>._domainkey.<domain> pointing to <t>.dkim.amazonses.com."
  value       = aws_ses_domain_dkim.rentivo.dkim_tokens
}
