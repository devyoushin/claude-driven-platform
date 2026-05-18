###############################################################################
# Security Hub - Organization-wide Security Posture Management
# CIS AWS Foundations Benchmark + AWS Foundational Security Best Practices
###############################################################################

# Security Hub 활성화
resource "aws_securityhub_account" "main" {}

# Organization 위임 관리자
resource "aws_securityhub_organization_admin_account" "main" {
  admin_account_id = data.aws_caller_identity.current.account_id

  depends_on = [
    aws_organizations_organization.main,
    aws_securityhub_account.main,
  ]
}

# Organization 전체 설정 - 신규 계정 자동 등록
resource "aws_securityhub_organization_configuration" "main" {
  auto_enable = true

  depends_on = [aws_securityhub_organization_admin_account.main]
}

###############################################################################
# Security Standards - 보안 표준 활성화
###############################################################################

# AWS Foundational Security Best Practices v1.0.0
resource "aws_securityhub_standards_subscription" "aws_best_practices" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# CIS AWS Foundations Benchmark v1.4.0
resource "aws_securityhub_standards_subscription" "cis_foundations" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

###############################################################################
# Security Hub Member Accounts
###############################################################################

resource "aws_securityhub_member" "service" {
  account_id = aws_organizations_account.service.id
  email      = var.service_account_email
  invite     = true

  depends_on = [aws_securityhub_organization_configuration.main]
}

resource "aws_securityhub_member" "operations" {
  account_id = aws_organizations_account.operations.id
  email      = var.operations_account_email
  invite     = true

  depends_on = [aws_securityhub_organization_configuration.main]
}

###############################################################################
# Security Hub Findings → SNS 알림 (CRITICAL / HIGH)
###############################################################################

resource "aws_sns_topic" "securityhub_findings" {
  name = "${local.name}-securityhub-findings"

  tags = merge(module.tags.tags, {
    Name = "${local.name}-securityhub-findings"
  })
}

resource "aws_sns_topic_policy" "securityhub_findings" {
  arn = aws_sns_topic.securityhub_findings.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.securityhub_findings.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "securityhub_critical" {
  name        = "${local.name}-securityhub-critical-findings"
  description = "Security Hub CRITICAL and HIGH severity findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = module.tags.tags
}

resource "aws_cloudwatch_event_target" "securityhub_sns" {
  rule      = aws_cloudwatch_event_rule.securityhub_critical.name
  target_id = "securityhub-to-sns"
  arn       = aws_sns_topic.securityhub_findings.arn
}
