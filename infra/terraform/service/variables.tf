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
  description = "Service VPC CIDR"
  type        = string
  default     = "10.10.0.0/16"
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID from Landing Zone"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "ec2_instance_type" {
  description = "EC2 instance type for standalone instances"
  type        = string
  default     = "t3.medium"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_engine_version" {
  description = "RDS PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_password" {
  description = "RDS master password (use terraform.tfvars or env var TF_VAR_rds_password)"
  type        = string
  sensitive   = true
}
