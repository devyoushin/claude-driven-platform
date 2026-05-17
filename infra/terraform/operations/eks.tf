###############################################################################
# EKS Cluster - 모니터링 스택 전용
###############################################################################

resource "aws_eks_cluster" "monitoring" {
  name     = "${local.name}-monitoring"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids              = module.vpc.private_app_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
  ]

  tags = merge(module.tags.tags, {
    Name = "${local.name}-monitoring"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

###############################################################################
# Managed Node Group
###############################################################################

resource "aws_eks_node_group" "monitoring" {
  cluster_name    = aws_eks_cluster.monitoring.name
  node_group_name = "${local.name}-monitoring-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = module.vpc.private_app_subnet_ids

  instance_types = var.eks_node_instance_types

  scaling_config {
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_desired_size * 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    Environment = var.environment
    Role        = "monitoring"
  }

  tags = merge(module.tags.tags, {
    Name = "${local.name}-monitoring-node"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy,
  ]
}

###############################################################################
# KMS Key
###############################################################################

resource "aws_kms_key" "eks" {
  description             = "KMS key for Operations EKS secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(module.tags.tags, {
    Name = "${local.name}-eks-kms"
  })
}

###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "eks_cluster" {
  name_prefix = "${local.name}-eks-"
  vpc_id      = module.vpc.vpc_id
  description = "Operations EKS cluster security group"

  ingress {
    description = "Worker nodes to cluster API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Service VPC (metric endpoints)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(module.tags.tags, {
    Name = "${local.name}-eks-sg"
  })
}

###############################################################################
# IAM Roles - EKS
###############################################################################

resource "aws_iam_role" "eks_cluster" {
  name = "${local.name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks_node" {
  name = "${local.name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}
