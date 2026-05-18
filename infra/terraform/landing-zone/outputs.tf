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

###############################################################################
# Security
###############################################################################

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = aws_guardduty_detector.main.id
}

output "securityhub_arn" {
  description = "Security Hub ARN"
  value       = aws_securityhub_account.main.arn
}

output "config_recorder_id" {
  description = "AWS Config Recorder ID"
  value       = aws_config_configuration_recorder.main.id
}

output "guardduty_sns_topic_arn" {
  description = "SNS topic for GuardDuty HIGH/CRITICAL findings"
  value       = aws_sns_topic.guardduty_findings.arn
}

output "securityhub_sns_topic_arn" {
  description = "SNS topic for Security Hub CRITICAL/HIGH findings"
  value       = aws_sns_topic.securityhub_findings.arn
}

output "config_sns_topic_arn" {
  description = "SNS topic for Config non-compliant findings"
  value       = aws_sns_topic.config_compliance.arn
}
