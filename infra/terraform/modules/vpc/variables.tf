variable "name" {
  description = "VPC name prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "private_app_subnets" {
  description = "List of private application subnet CIDRs"
  type        = list(string)
}

variable "private_db_subnets" {
  description = "List of private database subnet CIDRs"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
