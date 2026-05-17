###############################################################################
# Service Account - 서비스 운영 환경
# VPC + EKS + EC2 + RDS + Backup
###############################################################################

locals {
  name = "cdp-service"
  azs  = ["ap-northeast-2a", "ap-northeast-2c"]
}

# Tags
module "tags" {
  source      = "../modules/tags"
  environment = var.environment
  component   = "service"
}

# VPC
module "vpc" {
  source = "../modules/vpc"

  name     = local.name
  vpc_cidr = var.vpc_cidr
  azs      = local.azs

  public_subnets      = ["10.10.1.0/24", "10.10.2.0/24"]
  private_app_subnets = ["10.10.11.0/24", "10.10.12.0/24"]
  private_db_subnets  = ["10.10.21.0/24", "10.10.22.0/24"]

  tags = module.tags.tags
}

###############################################################################
# TGW Attachment - Landing Zone TGW에 연결
###############################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "service" {
  subnet_ids         = module.vpc.private_app_subnet_ids
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = module.vpc.vpc_id

  tags = merge(module.tags.tags, {
    Name = "${local.name}-tgw-attachment"
  })
}

# Landing Zone VPC로 가는 라우트 추가 (TGW 경유)
resource "aws_route" "to_landing_zone" {
  count                  = length(local.azs)
  route_table_id         = module.vpc.private_app_subnet_ids[count.index]
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = var.transit_gateway_id
}
