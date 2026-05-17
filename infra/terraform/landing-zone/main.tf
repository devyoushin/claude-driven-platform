###############################################################################
# Landing Zone - 외부 트래픽 진입점
# WAF → ALB → TGW → Service Account
###############################################################################

locals {
  name = "cdp-landing"
  azs  = ["ap-northeast-2a", "ap-northeast-2c"]
}

# Tags
module "tags" {
  source      = "../modules/tags"
  environment = var.environment
  component   = "landing-zone"
}

# VPC
module "vpc" {
  source = "../modules/vpc"

  name     = local.name
  vpc_cidr = var.vpc_cidr
  azs      = local.azs

  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  private_db_subnets  = []

  tags = module.tags.tags
}

# Transit Gateway
module "tgw" {
  source = "../modules/tgw"

  name = "cdp"

  vpc_attachments = {
    landing-zone = {
      vpc_id     = module.vpc.vpc_id
      subnet_ids = module.vpc.private_app_subnet_ids
    }
  }

  tags = module.tags.tags
}
