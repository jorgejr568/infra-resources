module "hooks_fyi" {
  source = "./projects/hooks-fyi"

  providers = {
    aws = aws.hooks_fyi
  }
}
