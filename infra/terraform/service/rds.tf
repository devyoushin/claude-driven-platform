###############################################################################
# RDS PostgreSQL - Multi-AZ
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnet"
  subnet_ids = module.vpc.private_db_subnet_ids

  tags = merge(module.tags.tags, {
    Name = "${local.name}-db-subnet-group"
  })
}

###############################################################################
# RDS Instance
###############################################################################

resource "aws_db_instance" "main" {
  identifier = "${local.name}-postgres"

  engine                = "postgres"
  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_allocated_storage * 5 # Auto-scaling up to 5x

  db_name  = "cdpdb"
  username = "cdpadmin"
  password = var.rds_password # 실제 운영에서는 Secrets Manager 사용 권장

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Backup
  backup_retention_period = 7
  backup_window           = "03:00-04:00" # KST 12:00-13:00
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Monitoring
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Protection
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-postgres-final"

  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(module.tags.tags, {
    Name = "${local.name}-postgres"
  })
}

###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "rds" {
  name_prefix = "${local.name}-rds-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for RDS PostgreSQL"

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_app.id]
  }

  tags = merge(module.tags.tags, {
    Name = "${local.name}-rds-sg"
  })
}

###############################################################################
# KMS Key for RDS Encryption
###############################################################################

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(module.tags.tags, {
    Name = "${local.name}-rds-kms"
  })
}

###############################################################################
# Enhanced Monitoring IAM Role
###############################################################################

resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}
