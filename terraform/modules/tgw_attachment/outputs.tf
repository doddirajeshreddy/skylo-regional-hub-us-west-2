output "tgw_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment (null if not created)."
  value       = length(aws_ec2_transit_gateway_vpc_attachment.this) > 0 ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}
