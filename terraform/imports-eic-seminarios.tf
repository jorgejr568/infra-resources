# Import blocks for adopting the existing eic-seminarios AWS resources.
# Import blocks must live in the root module and reference resources via the
# module path. Remove this file in a follow-up PR after the import apply succeeds.

import {
  to = module.eic_seminarios.aws_s3_bucket.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_versioning.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_server_side_encryption_configuration.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_public_access_block.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_ownership_controls.eic_seminarios
  id = "eic-seminarios"
}
import {
  to = module.eic_seminarios.aws_s3_bucket.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_server_side_encryption_configuration.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_ownership_controls.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_public_access_block.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_website_configuration.guide
  id = "guide.eic-seminarios.com"
}
import {
  to = module.eic_seminarios.aws_s3_bucket_policy.guide
  id = "guide.eic-seminarios.com"
}
