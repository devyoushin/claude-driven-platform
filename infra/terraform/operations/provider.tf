terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  backend "s3" {
    bucket         = "claude-platform-tfstate"
    key            = "operations/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "claude-driven-platform"
      ManagedBy = "terraform"
      Component = "operations"
    }
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.monitoring.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.monitoring.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.monitoring.name]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.monitoring.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.monitoring.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.monitoring.name]
    }
  }
}
