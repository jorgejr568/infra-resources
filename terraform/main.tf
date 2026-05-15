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

module "eic_seminarios" {
  source = "./projects/eic-seminarios"

  server_ipv4 = var.server_ipv4
  server_ipv6 = var.server_ipv6

  providers = {
    cloudflare = cloudflare
  }
}

module "joy_living" {
  source = "./projects/joy-living"

  server_ipv4 = var.server_ipv4
  server_ipv6 = var.server_ipv6

  providers = {
    cloudflare = cloudflare
  }
}

module "organizze_mcp" {
  source = "./projects/organizze-mcp"

  providers = {
    aws = aws.organizze_mcp
  }
}
