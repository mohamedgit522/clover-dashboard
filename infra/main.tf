module "ecr" {
  source   = "./modules/ecr"
  app_name = var.app_name
}

module "acm" {
  source      = "./modules/acm"
  domain_name = var.domain_name
}

module "apprunner" {
  source         = "./modules/apprunner"
  app_name       = var.app_name
  repository_url = module.ecr.repository_url
}

module "route53" {
  source                    = "./modules/route53"
  domain_name               = var.domain_name
  root_domain               = var.root_domain
  app_runner_url            = module.apprunner.service_url
  domain_validation_options = module.acm.domain_validation_options
}
