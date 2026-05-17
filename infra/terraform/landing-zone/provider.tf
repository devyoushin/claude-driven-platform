terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend - apply 전에 S3 버킷과 DynamoDB 테이블을 먼저 생성해야 함
  backend "s3" {
    bucket         = "claude-platform-tfstate"
    key            = "landing-zone/terraform.tfstate"
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
      Component = "landing-zone"
    }
  }
}
