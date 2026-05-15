terraform {
  backend "s3" {
    bucket       = "jorgejr568-aws-resources-tfstate"
    key          = "aws-resources.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
