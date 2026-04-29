provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "aws-resources"
      Project   = "hooks-fyi"
    }
  }
}
