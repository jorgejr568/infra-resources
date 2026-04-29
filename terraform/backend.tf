terraform {
  backend "s3" {
    bucket         = "hooks-fyi-tfstate"
    key            = "aws-resources/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hooks-fyi-tflock"
    encrypt        = true
  }
}
