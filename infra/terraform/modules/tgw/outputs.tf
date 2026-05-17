output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_route_table_id" {
  description = "Transit Gateway Route Table ID"
  value       = aws_ec2_transit_gateway_route_table.this.id
}

output "vpc_attachment_ids" {
  description = "Map of VPC attachment IDs"
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.attachments : k => v.id }
}
