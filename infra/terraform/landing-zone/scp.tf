###############################################################################
# Service Control Policies (SCP)
# 조직 전체에 보안 가드레일 적용
###############################################################################

###############################################################################
# 1. 리전 제한 - ap-northeast-2 (Seoul) + Global 서비스만 허용
###############################################################################

resource "aws_organizations_policy" "region_restriction" {
  name        = "cdp-region-restriction"
  description = "Restrict all actions to ap-northeast-2 except global services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonApprovedRegions"
        Effect = "Deny"
        NotAction = [
          "a4b:*",
          "acm:*",
          "aws-marketplace-management:*",
          "aws-marketplace:*",
          "aws-portal:*",
          "budgets:*",
          "ce:*",
          "chime:*",
          "cloudfront:*",
          "config:*",
          "cur:*",
          "directconnect:*",
          "ec2:DescribeRegions",
          "ec2:DescribeTransitGateways",
          "ec2:DescribeVpnGateways",
          "fms:*",
          "globalaccelerator:*",
          "health:*",
          "iam:*",
          "importexport:*",
          "kms:*",
          "mobileanalytics:*",
          "networkmanager:*",
          "organizations:*",
          "pricing:*",
          "route53:*",
          "route53domains:*",
          "route53-recovery-cluster:*",
          "route53-recovery-control-config:*",
          "route53-recovery-readiness:*",
          "s3:GetBucketLocation",
          "s3:ListAllMyBuckets",
          "shield:*",
          "sts:*",
          "support:*",
          "trustedadvisor:*",
          "waf-regional:*",
          "waf:*",
          "wafv2:*",
          "wellarchitected:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = ["ap-northeast-2"]
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "region_restriction_workload" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.workload.id
}

resource "aws_organizations_policy_attachment" "region_restriction_operations" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.operations.id
}

###############################################################################
# 2. Root 사용자 제한
###############################################################################

resource "aws_organizations_policy" "deny_root" {
  name        = "cdp-deny-root-actions"
  description = "Deny all actions by root user in member accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootUser"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_root_workload" {
  policy_id = aws_organizations_policy.deny_root.id
  target_id = aws_organizations_organizational_unit.workload.id
}

resource "aws_organizations_policy_attachment" "deny_root_operations" {
  policy_id = aws_organizations_policy.deny_root.id
  target_id = aws_organizations_organizational_unit.operations.id
}

###############################################################################
# 3. IAM User 직접 생성 금지 (SSO만 사용 강제)
###############################################################################

resource "aws_organizations_policy" "deny_iam_user_creation" {
  name        = "cdp-deny-iam-user-creation"
  description = "Deny creating IAM users - enforce SSO usage"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMUserCreation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:CreateLoginProfile"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_iam_user_workload" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = aws_organizations_organizational_unit.workload.id
}

resource "aws_organizations_policy_attachment" "deny_iam_user_operations" {
  policy_id = aws_organizations_policy.deny_iam_user_creation.id
  target_id = aws_organizations_organizational_unit.operations.id
}

###############################################################################
# 4. CloudTrail 비활성화 방지
###############################################################################

resource "aws_organizations_policy" "protect_cloudtrail" {
  name        = "cdp-protect-cloudtrail"
  description = "Prevent disabling or deleting CloudTrail"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "protect_cloudtrail_workload" {
  policy_id = aws_organizations_policy.protect_cloudtrail.id
  target_id = aws_organizations_organizational_unit.workload.id
}

resource "aws_organizations_policy_attachment" "protect_cloudtrail_operations" {
  policy_id = aws_organizations_policy.protect_cloudtrail.id
  target_id = aws_organizations_organizational_unit.operations.id
}

###############################################################################
# 5. Tag Policy - 필수 태그 강제
###############################################################################

resource "aws_organizations_policy" "tag_policy" {
  name        = "cdp-tag-policy"
  description = "Enforce required tags on all resources"
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      Project = {
        tag_key = {
          "@@assign" = "Project"
        }
        tag_value = {
          "@@assign" = ["claude-driven-platform"]
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "ec2:vpc",
            "ec2:subnet",
            "rds:db",
            "eks:cluster",
            "s3:bucket",
            "lambda:function"
          ]
        }
      }
      Environment = {
        tag_key = {
          "@@assign" = "Environment"
        }
        tag_value = {
          "@@assign" = ["dev", "staging", "prod"]
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "ec2:vpc",
            "rds:db",
            "eks:cluster"
          ]
        }
      }
      ManagedBy = {
        tag_key = {
          "@@assign" = "ManagedBy"
        }
        tag_value = {
          "@@assign" = ["terraform"]
        }
      }
    }
  })
}

resource "aws_organizations_policy_attachment" "tag_policy_root" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = aws_organizations_organization.main.roots[0].id
}
