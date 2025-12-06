variable "project" {
  description = "Project name prefix."
  type        = string
  default     = "skylo-regional-hub"
}

variable "vpc_cidr" {
  description = "CIDR block for the Regional Hub VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability Zones to use for this hub."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "tgw_id" {
  description = "Mock Transit Gateway ID. Leave empty to skip TGW attachment."
  type        = string
  default     = ""
}

variable "dx_on_prem_cidrs" {
  description = "On-prem / ground-station CIDRs routed via the TGW from app subnets."
  type        = list(string)
  default     = []
}
