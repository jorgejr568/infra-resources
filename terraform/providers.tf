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

provider "cloudflare" {
  # API token comes from CLOUDFLARE_API_TOKEN env var in CI; no per-project
  # alias because Cloudflare has no provider-level tagging concept.
}
