# Tag Policy Module
# 모든 리소스에 일관된 태그를 적용하기 위한 모듈

variable "project" {
  description = "Project name"
  type        = string
  default     = "claude-driven-platform"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "component" {
  description = "Component name (landing-zone/service/monitoring)"
  type        = string
}

variable "owner" {
  description = "Resource owner"
  type        = string
  default     = "devyoushin"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "platform"
}

variable "extra_tags" {
  description = "Additional tags to merge"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Component   = var.component
    },
    var.extra_tags
  )
}

output "tags" {
  description = "Common tags to apply to all resources"
  value       = local.common_tags
}
