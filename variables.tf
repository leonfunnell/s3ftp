variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

variable "tf_state_bucket" {
  type        = string
  description = "S3 bucket name to store Terraform state"
}
