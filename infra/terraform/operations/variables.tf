variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "Operations VPC CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID from Landing Zone"
  type        = string
}

variable "service_account_id" {
  description = "Service Account AWS Account ID (for cross-account access)"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version for monitoring cluster"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for monitoring EKS nodes"
  type        = list(string)
  default     = ["t3.large"]  # 모니터링은 메모리 사용량이 높아 large 사용
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}
