###############################################################################
# AWS Organizations - 멀티 계정 거버넌스
###############################################################################

resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "sso.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "backup.amazonaws.com",
  ]

  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]
}

###############################################################################
# Organizational Units (OU)
###############################################################################

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "workload" {
  name      = "Workload"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "operations" {
  name      = "Operations"
  parent_id = aws_organizations_organization.main.roots[0].id
}

###############################################################################
# Member Accounts
###############################################################################

resource "aws_organizations_account" "service" {
  name      = "cdp-service"
  email     = var.service_account_email
  parent_id = aws_organizations_organizational_unit.workload.id
  role_name = "OrganizationAccountAccessRole"

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(module.tags.tags, {
    AccountType = "service"
  })
}

resource "aws_organizations_account" "operations" {
  name      = "cdp-operations"
  email     = var.operations_account_email
  parent_id = aws_organizations_organizational_unit.operations.id
  role_name = "OrganizationAccountAccessRole"

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(module.tags.tags, {
    AccountType = "operations"
  })
}
