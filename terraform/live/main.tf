#############
## DNS
#############

locals {
  hosted_zone_name    = "starknet-snap.consensys-solutions.net"
  hosted_zone_id      = aws_route53_zone.main.zone_id
  dev_domain_name     = "app-dev.${local.hosted_zone_name}"
  staging_domain_name = "app-staging.${local.hosted_zone_name}"
  prod_domain_name    = "app.${local.hosted_zone_name}"

  # snaps 
  snaps_hosted_zone_name = "snaps.consensys.net"
  snaps_hosted_zone_id   = aws_route53_zone.snaps.zone_id
  dev_snaps_domain_name  = "dev.${local.snaps_hosted_zone_name}"
}

resource "aws_route53_zone" "main" {
  name = local.hosted_zone_name
  tags = module.tags.common
}

resource "aws_route53_zone" "snaps" {
  name = local.snaps_hosted_zone_name
  tags = module.tags.common
}

#############
## Certificate
#############

module "cert" {
  source  = "terraform-aws-modules/acm/aws"
  version = "3.5.0"

  providers = {
    aws = aws.use1
  }

  subject_alternative_names = ["*.starknet-snap.consensys-solutions.net"]
  wait_for_validation       = true
  domain_name               = local.hosted_zone_name
  zone_id                   = local.hosted_zone_id
  tags                      = module.tags.common
}

module "snaps_cert" {
  source  = "terraform-aws-modules/acm/aws"
  version = "3.5.0"

  providers = {
    aws = aws.use1
  }

  subject_alternative_names = ["*.${local.snaps_hosted_zone_name}"]
  wait_for_validation       = true
  domain_name               = local.snaps_hosted_zone_name
  zone_id                   = local.snaps_hosted_zone_id
  tags                      = module.tags.common
}

#############
## Cloufront configurations
#############

resource "aws_cloudfront_function" "starknet_redirect" {
  name    = "starknet-snap-redirect"
  runtime = "cloudfront-js-1.0"
  comment = "starknet-snap-redirect"
  publish = true
  code    = file("${path.module}/functions/redirect.js")
}

module "security_header_lambda" {
  source = "../modules/lambda-at-edge"

  bucket_name            = local.dev_domain_name
  lambda_name            = "security_headers"
  lambda_description     = "lambda adding security headers"
  lambda_code_source_dir = "${path.root}/lambdas"
  tags                   = module.tags.common
}

#############
## Dev
#############

module "s3_dev" {
  source = "../modules/aws-s3-website"

  bucket_name         = local.dev_domain_name
  domain_name         = local.dev_domain_name
  certificate_arn     = module.cert.acm_certificate_arn
  hosted_zone_id      = local.hosted_zone_id
  lambda_function_arn = [module.security_header_lambda.function_arn]
  tags                = module.tags.common
}

module "s3_snaps_page_dev" {
  source = "../modules/aws-s3-website"

  bucket_name     = local.dev_snaps_domain_name
  domain_name     = local.dev_snaps_domain_name
  certificate_arn = module.snaps_cert.acm_certificate_arn
  hosted_zone_id  = local.hosted_zone_id
  function_arn    = [aws_cloudfront_function.starknet_redirect.arn]
  tags            = module.tags.common
}

#############
## Staging
#############

module "s3_staging" {
  source = "../modules/aws-s3-website"

  bucket_name         = local.staging_domain_name
  domain_name         = local.staging_domain_name
  certificate_arn     = module.cert.acm_certificate_arn
  hosted_zone_id      = local.hosted_zone_id
  lambda_function_arn = [module.security_header_lambda.function_arn]
  tags                = module.tags.common
}

#############
## Prod
#############

module "s3_prod" {
  source = "../modules/aws-s3-website"

  bucket_name         = local.prod_domain_name
  domain_name         = local.prod_domain_name
  certificate_arn     = module.cert.acm_certificate_arn
  hosted_zone_id      = local.hosted_zone_id
  lambda_function_arn = [module.security_header_lambda.function_arn]
  tags                = module.tags.common
}
