###############################################################################
# GuardDuty - Organization-wide Threat Detection
# Landing Zone 계정에서 위임 관리자로 설정, 전 계정 자동 활성화
###############################################################################

# Landing Zone 계정의 GuardDuty 탐지기
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }

    kubernetes {
      audit_logs {
        enable = true
      }
    }

    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = merge(module.tags.tags, {
    Name = "${local.name}-guardduty"
  })
}

# Organization 위임 관리자 설정 (Landing Zone → 관리 계정)
resource "aws_guardduty_organization_admin_account" "main" {
  admin_account_id = data.aws_caller_identity.current.account_id

  depends_on = [aws_organizations_organization.main]
}

# Organization 전체 설정 - 신규 계정 자동 등록
resource "aws_guardduty_organization_configuration" "main" {
  detector_id = aws_guardduty_detector.main.id
  auto_enable_organization_members = "ALL"

  datasources {
    s3_logs {
      auto_enable = true
    }

    kubernetes {
      audit_logs {
        auto_enable = true
      }
    }

    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = true
        }
      }
    }
  }

  depends_on = [aws_guardduty_organization_admin_account.main]
}

# Service Account를 멤버로 등록
resource "aws_guardduty_member" "service" {
  detector_id = aws_guardduty_detector.main.id
  account_id  = aws_organizations_account.service.id
  email       = var.service_account_email
  invite      = true

  lifecycle {
    ignore_changes = [email]
  }

  depends_on = [aws_guardduty_organization_configuration.main]
}

# Operations Account를 멤버로 등록
resource "aws_guardduty_member" "operations" {
  detector_id = aws_guardduty_detector.main.id
  account_id  = aws_organizations_account.operations.id
  email       = var.operations_account_email
  invite      = true

  lifecycle {
    ignore_changes = [email]
  }

  depends_on = [aws_guardduty_organization_configuration.main]
}

###############################################################################
# GuardDuty Findings → SNS 알림
###############################################################################

resource "aws_sns_topic" "guardduty_findings" {
  name = "${local.name}-guardduty-findings"

  tags = merge(module.tags.tags, {
    Name = "${local.name}-guardduty-findings"
  })
}

resource "aws_sns_topic_policy" "guardduty_findings" {
  arn = aws_sns_topic.guardduty_findings.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.guardduty_findings.arn
      }
    ]
  })
}

# EventBridge Rule - HIGH/CRITICAL severity findings만 알림
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${local.name}-guardduty-high-findings"
  description = "GuardDuty HIGH/CRITICAL severity findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = module.tags.tags
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high.name
  target_id = "guardduty-to-sns"
  arn       = aws_sns_topic.guardduty_findings.arn
}
