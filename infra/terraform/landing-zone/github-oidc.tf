###############################################################################
# GitHub OIDC Provider
# GitHub Actions가 Access Key 없이 AWS에 인증하기 위한 설정
# Landing Zone에서 생성 후 각 계정에 Role을 만들어 사용
###############################################################################

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(module.tags.tags, {
    Name = "github-actions-oidc"
  })
}

###############################################################################
# GitHub Actions Role - Landing Zone
###############################################################################

resource "aws_iam_role" "github_actions_landing" {
  name = "cdp-github-actions-landing-zone"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "github_landing_admin" {
  role       = aws_iam_role.github_actions_landing.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

###############################################################################
# Outputs for GitHub Secrets
###############################################################################

output "github_oidc_provider_arn" {
  description = "GitHub OIDC Provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_landing_zone" {
  description = "GitHub Actions IAM Role ARN for Landing Zone"
  value       = aws_iam_role.github_actions_landing.arn
}
