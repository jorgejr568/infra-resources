module "hooks_fyi" {
  source = "./projects/hooks-fyi"

  server_ipv4 = var.server_ipv4
  server_ipv6 = var.server_ipv6

  providers = {
    aws        = aws.hooks_fyi
    cloudflare = cloudflare
  }
}

module "rentivo" {
  source = "./projects/rentivo"

  server_ipv4 = var.server_ipv4
  server_ipv6 = var.server_ipv6

  providers = {
    aws        = aws.rentivo
    cloudflare = cloudflare
  }
}

module "jorgejunior" {
  source = "./projects/jorgejunior"

  server_ipv4 = var.server_ipv4
  server_ipv6 = var.server_ipv6

  providers = {
    cloudflare = cloudflare
  }
}
