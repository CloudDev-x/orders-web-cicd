variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name, used in resource names"
  type        = string
  default     = "orders-web-cicd"
}

variable "initial_image_tag" {
  description = "Image tag used for the first task definition. Later deploys come from the pipeline."
  type        = string
  default     = "b6f35ce"
}
