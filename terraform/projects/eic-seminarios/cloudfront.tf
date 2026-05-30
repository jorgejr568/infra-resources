resource "aws_acm_certificate" "guide" {
  domain_name       = "guide.eic-seminarios.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM DNS-validation CNAME (already present in Cloudflare; imported).
resource "cloudflare_dns_record" "acm_guide_validation" {
  zone_id = data.cloudflare_zone.eic_seminarios.id
  name    = "_96edaf591a8248fcdf34a050fe98e34c.guide.eic-seminarios.com"
  type    = "CNAME"
  content = "_22162c9f330487ff0020c1cd040af1da.jkddzztszm.acm-validations.aws"
  ttl     = 1
  proxied = false
}

resource "aws_acm_certificate_validation" "guide" {
  certificate_arn         = aws_acm_certificate.guide.arn
  validation_record_fqdns = [cloudflare_dns_record.acm_guide_validation.name]
}

resource "aws_cloudfront_distribution" "guide" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2"
  price_class         = "PriceClass_All"
  aliases             = ["guide.eic-seminarios.com"]
  default_root_object = "index.html"
  comment             = "CEFET-RJ Seminarios Guide Documentation"

  origin {
    origin_id   = "S3-guide"
    domain_name = "guide.eic-seminarios.com.s3-website-us-east-1.amazonaws.com"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  default_cache_behavior {
    target_origin_id       = "S3-guide"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.guide.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

output "guide_distribution_id" {
  description = "CloudFront distribution ID serving guide.eic-seminarios.com."
  value       = aws_cloudfront_distribution.guide.id
}
