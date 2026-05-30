provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
    }
  }
}

provider "aws" {
  alias  = "hooks_fyi"
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
      Project   = "hooks-fyi"
    }
  }
}

provider "aws" {
  alias  = "rentivo"
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
      Project   = "rentivo"
    }
  }
}

provider "aws" {
  alias  = "organizze_mcp"
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
      Project   = "organizze-mcp"
    }
  }
}

provider "aws" {
  alias  = "eic_seminarios"
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
      Project   = "eic-seminarios"
    }
  }
}

provider "cloudflare" {
  # API token comes from CLOUDFLARE_API_TOKEN env var in CI; no per-project
  # alias because Cloudflare has no provider-level tagging concept.
}
