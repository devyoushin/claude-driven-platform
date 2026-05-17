# Transit Gateway Module
# Landing Zone ↔ Service Account 간 네트워크 연결

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

###############################################################################
# Transit Gateway
###############################################################################

resource "aws_ec2_transit_gateway" "this" {
  description                     = "${var.name} Transit Gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"

  tags = merge(var.tags, {
    Name = "${var.name}-tgw"
  })
}

###############################################################################
# TGW Route Table
###############################################################################

resource "aws_ec2_transit_gateway_route_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt"
  })
}

###############################################################################
# VPC Attachments
###############################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "attachments" {
  for_each = var.vpc_attachments

  subnet_ids         = each.value.subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-attach-${each.key}"
  })
}

###############################################################################
# Route Table Associations
###############################################################################

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = var.vpc_attachments

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachments[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}

###############################################################################
# Route Table Propagations
###############################################################################

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = var.vpc_attachments

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachments[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this.id
}
