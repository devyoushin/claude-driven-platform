variable "name" {
  description = "Transit Gateway name prefix"
  type        = string
}

variable "vpc_attachments" {
  description = "Map of VPC attachments"
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
  }))
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
