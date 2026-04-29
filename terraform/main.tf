module "hooks_fyi" {
  source = "./projects/hooks-fyi"

  providers = {
    aws = aws.hooks_fyi
  }
}

module "rentivo" {
  source = "./projects/rentivo"

  providers = {
    aws = aws.rentivo
  }
}
