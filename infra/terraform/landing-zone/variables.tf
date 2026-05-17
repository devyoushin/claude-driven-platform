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
  description = "Landing Zone VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

###############################################################################
# Organizations & Identity Center
###############################################################################

variable "service_account_email" {
  description = "Email for Service Account (must be unique across AWS)"
  type        = string
}

variable "operations_account_email" {
  description = "Email for Operations Account (must be unique across AWS)"
  type        = string
}
