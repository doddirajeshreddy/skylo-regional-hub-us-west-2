output "vpc_id" {
  description = "ID of the Regional Hub VPC."
  value       = aws_vpc.this.id
}

output "private_app_subnet_ids" {
  description = "Private-App subnet IDs where EKS worker nodes and internal NLBs will live."
  value       = [for s in aws_subnet.private_app : s.id]
}

output "private_app_route_table_ids" {
  description = "Route table IDs for the Private-App subnets."
  value       = [for rt in aws_route_table.private_app : rt.id]
}
