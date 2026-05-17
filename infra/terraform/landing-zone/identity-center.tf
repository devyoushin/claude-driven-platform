###############################################################################
# IAM Identity Center (SSO)
# 중앙 집중식 사용자 인증 및 권한 관리
###############################################################################

data "aws_ssoadmin_instances" "main" {}

locals {
  sso_instance_arn = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

###############################################################################
# Groups
###############################################################################

resource "aws_identitystore_group" "platform_admins" {
  display_name      = "platform-admins"
  description       = "Full administrator access to all accounts"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "developers" {
  display_name      = "developers"
  description       = "Deploy and manage Service Account workloads"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "sre_team" {
  display_name      = "sre-team"
  description       = "Manage Operations Account monitoring stack"
  identity_store_id = local.identity_store_id
}

resource "aws_identitystore_group" "viewers" {
  display_name      = "viewers"
  description       = "Read-only access to all accounts"
  identity_store_id = local.identity_store_id
}

###############################################################################
# Permission Sets
###############################################################################

# Administrator Access - Landing Zone only
resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccess"
  description      = "Full admin access"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"  # 4시간 세션
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

# Service Deploy Access - Service Account
resource "aws_ssoadmin_permission_set" "service_deploy" {
  name             = "ServiceDeployAccess"
  description      = "Deploy and manage workloads in Service Account"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"  # 8시간 세션 (개발 업무)
}

resource "aws_ssoadmin_permission_set_inline_policy" "service_deploy" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.service_deploy.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:*",
          "ecr:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Access"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "autoscaling:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDestructive"
        Effect = "Deny"
        Action = [
          "rds:DeleteDBInstance",
          "rds:DeleteDBCluster",
          "ec2:TerminateInstances",
          "eks:DeleteCluster",
        ]
        Resource = "*"
      }
    ]
  })
}

# Service Read Only - Service Account
resource "aws_ssoadmin_permission_set" "service_readonly" {
  name             = "ServiceReadOnly"
  description      = "Read-only access to Service Account"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT12H"
}

resource "aws_ssoadmin_managed_policy_attachment" "service_readonly" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.service_readonly.arn
}

# Operations Full Access - Operations Account
resource "aws_ssoadmin_permission_set" "ops_full" {
  name             = "OperationsFullAccess"
  description      = "Full access to Operations Account for SRE team"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
}

resource "aws_ssoadmin_permission_set_inline_policy" "ops_full" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ops_full.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSFullAccess"
        Effect = "Allow"
        Action = [
          "eks:*",
          "ecr:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "MonitoringAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*",
          "sns:*",
          "lambda:*",
          "grafana:*",
          "prometheus:*",
          "aps:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ForMonitoring"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDestructive"
        Effect = "Deny"
        Action = [
          "eks:DeleteCluster",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
        ]
        Resource = "*"
      }
    ]
  })
}

# View Only Access - All Accounts
resource "aws_ssoadmin_permission_set" "view_only" {
  name             = "ViewOnlyAccess"
  description      = "View-only access for auditing"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT12H"
}

resource "aws_ssoadmin_managed_policy_attachment" "view_only" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.view_only.arn
}

###############################################################################
# Account Assignments - Group ↔ Permission Set ↔ Account 연결
###############################################################################

# platform-admins → AdministratorAccess → Landing Zone
resource "aws_ssoadmin_account_assignment" "admin_landing" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = aws_identitystore_group.platform_admins.group_id
  principal_type     = "GROUP"
  target_id          = data.aws_caller_identity.current.account_id
  target_type        = "AWS_ACCOUNT"
}

# developers → ServiceDeployAccess → Service Account
resource "aws_ssoadmin_account_assignment" "dev_service" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.service_deploy.arn
  principal_id       = aws_identitystore_group.developers.group_id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.service.id
  target_type        = "AWS_ACCOUNT"
}

# sre-team → OperationsFullAccess → Operations Account
resource "aws_ssoadmin_account_assignment" "sre_ops" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.ops_full.arn
  principal_id       = aws_identitystore_group.sre_team.group_id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.operations.id
  target_type        = "AWS_ACCOUNT"
}

# sre-team → ServiceReadOnly → Service Account (모니터링을 위한 읽기 접근)
resource "aws_ssoadmin_account_assignment" "sre_service_readonly" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.service_readonly.arn
  principal_id       = aws_identitystore_group.sre_team.group_id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.service.id
  target_type        = "AWS_ACCOUNT"
}

# viewers → ViewOnlyAccess → All Accounts
resource "aws_ssoadmin_account_assignment" "viewers_landing" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.view_only.arn
  principal_id       = aws_identitystore_group.viewers.group_id
  principal_type     = "GROUP"
  target_id          = data.aws_caller_identity.current.account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "viewers_service" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.view_only.arn
  principal_id       = aws_identitystore_group.viewers.group_id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.service.id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "viewers_ops" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.view_only.arn
  principal_id       = aws_identitystore_group.viewers.group_id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.operations.id
  target_type        = "AWS_ACCOUNT"
}

###############################################################################
# Data Sources
###############################################################################

data "aws_caller_identity" "current" {}
