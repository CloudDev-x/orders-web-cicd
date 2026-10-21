variable "aws_region" {
  description = "Region for the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "orders-web-cicd"
}
