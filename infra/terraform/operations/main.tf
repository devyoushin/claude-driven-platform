###############################################################################
# Operations Account - 모니터링/옵저버빌리티 전용
# Prometheus + Grafana + AlertManager on EKS
###############################################################################

locals {
  name = "cdp-ops"
  azs  = ["ap-northeast-2a", "ap-northeast-2c"]
}

# Tags
module "tags" {
  source      = "../modules/tags"
  environment = var.environment
  component   = "operations"
}

###############################################################################
# VPC
###############################################################################

module "vpc" {
  source = "../modules/vpc"

  name     = local.name
  vpc_cidr = var.vpc_cidr
  azs      = local.azs

  public_subnets      = ["10.20.1.0/24", "10.20.2.0/24"]
  private_app_subnets = ["10.20.11.0/24", "10.20.12.0/24"]
  private_db_subnets  = [] # Operations에는 DB 불필요

  tags = module.tags.tags
}

###############################################################################
# TGW Attachment - Service Account 메트릭 수집을 위한 연결
###############################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "operations" {
  subnet_ids         = module.vpc.private_app_subnet_ids
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = module.vpc.vpc_id

  tags = merge(module.tags.tags, {
    Name = "${local.name}-tgw-attachment"
  })
}

# Service VPC로의 라우트 (Prometheus가 Service Account 메트릭을 scrape)
resource "aws_route" "to_service" {
  count                  = length(local.azs)
  route_table_id         = module.vpc.private_app_subnet_ids[count.index]
  destination_cidr_block = "10.10.0.0/16" # Service VPC CIDR
  transit_gateway_id     = var.transit_gateway_id
}
