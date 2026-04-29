terraform {
  backend "s3" {
    bucket         = "jorgejr568-aws-resources-tfstate"
    key            = "projects/hooks-fyi/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-resources-tflock"
    encrypt        = true
  }
}
