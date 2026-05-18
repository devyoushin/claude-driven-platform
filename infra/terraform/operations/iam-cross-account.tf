###############################################################################
# Cross-Account IAM - Service Account 메트릭 읽기 전용 접근
###############################################################################

# Operations → Service Account AssumeRole (읽기 전용)
# 이 Role은 Service Account 쪽에 생성되어야 하지만,
# 여기서는 Operations 측에서 assume할 정책을 정의

resource "aws_iam_policy" "cross_account_metrics" {
  name        = "${local.name}-cross-account-metrics"
  description = "Allow assuming role in Service Account for metrics collection"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.service_account_id}:role/cdp-service-readonly-role"
      }
    ]
  })

  tags = module.tags.tags
}

# EKS Node Role에 cross-account 정책 연결
resource "aws_iam_role_policy_attachment" "eks_node_cross_account" {
  policy_arn = aws_iam_policy.cross_account_metrics.arn
  role       = aws_iam_role.eks_node.name
}

###############################################################################
# CloudWatch Cross-Account Sharing
# Service Account의 CloudWatch 메트릭을 Operations에서 볼 수 있도록
###############################################################################

resource "aws_iam_policy" "cloudwatch_cross_account" {
  name        = "${local.name}-cloudwatch-cross-account"
  description = "Allow reading CloudWatch metrics from Service Account"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "logs:GetLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
        }
      }
    ]
  })

  tags = module.tags.tags
}

###############################################################################
# Prometheus IRSA - Service Account 메트릭 수집용
###############################################################################

data "aws_iam_policy_document" "prometheus_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.monitoring.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:monitoring:kube-prometheus-stack-prometheus"]
    }
  }
}

resource "aws_iam_role" "prometheus" {
  name               = "${local.name}-prometheus-role"
  assume_role_policy = data.aws_iam_policy_document.prometheus_assume.json
  tags               = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "prometheus_cross_account" {
  policy_arn = aws_iam_policy.cross_account_metrics.arn
  role       = aws_iam_role.prometheus.name
}

resource "aws_iam_role_policy_attachment" "prometheus_cloudwatch" {
  policy_arn = aws_iam_policy.cloudwatch_cross_account.arn
  role       = aws_iam_role.prometheus.name
}
