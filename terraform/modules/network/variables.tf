variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability Zones to create subnets in."
  type        = list(string)
}
