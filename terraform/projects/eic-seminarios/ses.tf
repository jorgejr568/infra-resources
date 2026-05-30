# New, project-owned configuration set (replaces the console default
# "my-first-configuration-set" as the identities' default). Same settings.
resource "aws_sesv2_configuration_set" "main" {
  configuration_set_name = "eic-seminarios"

  reputation_options {
    reputation_metrics_enabled = true
  }

  sending_options {
    sending_enabled = true
  }
}

resource "aws_sesv2_configuration_set_event_destination" "dashboard" {
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
  event_destination_name = "eic-seminarios-ses-dashboard"

  event_destination {
    enabled = true
    matching_event_types = [
      "SEND",
      "REJECT",
      "BOUNCE",
      "COMPLAINT",
      "DELIVERY",
      "OPEN",
      "CLICK",
      "RENDERING_FAILURE",
      "DELIVERY_DELAY",
    ]

    cloud_watch_destination {
      dimension_configuration {
        default_dimension_value = "eic-seminarios-ses"
        dimension_name          = "origin"
        dimension_value_source  = "MESSAGE_TAG"
      }
    }
  }
}

resource "aws_sesv2_email_identity" "eic_seminarios" {
  email_identity         = "eic-seminarios.com"
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
}

resource "aws_sesv2_email_identity_mail_from_attributes" "eic_seminarios" {
  email_identity         = aws_sesv2_email_identity.eic_seminarios.email_identity
  mail_from_domain       = "ses.eic-seminarios.com"
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

resource "aws_sesv2_email_identity" "no_reply" {
  email_identity         = "no-reply@eic-seminarios.com"
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
}

output "eic_seminarios_dkim_tokens" {
  description = "SES Easy DKIM tokens for eic-seminarios.com. For each token <t>, a CNAME at <t>._domainkey.eic-seminarios.com points to <t>.dkim.amazonses.com (already in Cloudflare, manually managed)."
  value       = aws_sesv2_email_identity.eic_seminarios.dkim_signing_attributes[0].tokens
}
