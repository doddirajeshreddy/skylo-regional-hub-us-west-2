variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to attach to the Transit Gateway."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used for the VPC attachment (private app subnets)."
  type        = list(string)
}

variable "tgw_id" {
  description = "Transit Gateway ID. If empty, TGW resources are skipped."
  type        = string
}

variable "route_table_ids" {
  description = "Private-App route table IDs where TGW routes will be added."
  type        = list(string)
}

variable "dx_on_prem_cidrs" {
  description = "On-prem / ground-station CIDRs reachable via the Transit Gateway."
  type        = list(string)
}
