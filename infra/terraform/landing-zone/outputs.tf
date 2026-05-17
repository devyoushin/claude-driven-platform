output "vpc_id" {
  description = "Landing Zone VPC ID"
  value       = module.vpc.vpc_id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID (share with Service account)"
  value       = module.tgw.transit_gateway_id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

###############################################################################
# Organizations
###############################################################################

output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.main.id
}

output "service_account_id" {
  description = "Service Account AWS Account ID"
  value       = aws_organizations_account.service.id
}

output "operations_account_id" {
  description = "Operations Account AWS Account ID"
  value       = aws_organizations_account.operations.id
}

output "sso_portal_url" {
  description = "IAM Identity Center SSO Portal URL"
  value       = "https://cdp.awsapps.com/start"
}
