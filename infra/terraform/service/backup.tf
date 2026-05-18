###############################################################################
# AWS Backup - 중앙 집중식 백업 관리
###############################################################################

resource "aws_backup_vault" "main" {
  name        = "${local.name}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = merge(module.tags.tags, {
    Name = "${local.name}-backup-vault"
  })
}

###############################################################################
# Backup Plan
###############################################################################

resource "aws_backup_plan" "main" {
  name = "${local.name}-backup-plan"

  # Daily backup - 7일 보관
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 18 * * ? *)" # UTC 18:00 = KST 03:00

    lifecycle {
      delete_after = 7
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.main.arn
      lifecycle {
        delete_after = 7
      }
    }
  }

  # Weekly backup - 30일 보관
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 18 ? * SUN *)" # 매주 일요일

    lifecycle {
      delete_after = 30
    }
  }

  # Monthly backup - 365일 보관
  rule {
    rule_name         = "monthly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 18 1 * ? *)" # 매월 1일

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }
  }

  tags = module.tags.tags
}

###############################################################################
# Backup Selection - 어떤 리소스를 백업할지
###############################################################################

resource "aws_backup_selection" "main" {
  name         = "${local.name}-backup-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.main.id

  # 태그 기반 선택 - Backup = true 태그가 있는 모든 리소스
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  # 추가로 특정 리소스 직접 지정
  resources = [
    aws_db_instance.main.arn,
  ]
}

###############################################################################
# KMS Key for Backup Vault
###############################################################################

resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup vault encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(module.tags.tags, {
    Name = "${local.name}-backup-kms"
  })
}

###############################################################################
# IAM Role for AWS Backup
###############################################################################

resource "aws_iam_role" "backup" {
  name = "${local.name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}
