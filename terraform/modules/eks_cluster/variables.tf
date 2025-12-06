variable "project" {
  description = "Project name prefix for AWS Managed EKS."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the EKS control plane ENIs."
  type        = list(string)
}
