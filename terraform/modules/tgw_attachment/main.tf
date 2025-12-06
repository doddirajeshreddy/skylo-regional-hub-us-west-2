###################################
# TGW VPC ATTACHMENT
###################################

# Only create attachment if a TGW ID is provided
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = var.tgw_id == "" ? 0 : 1

  transit_gateway_id = var.tgw_id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  tags = {
    Name = "${var.project}-tgw-attachment"
  }
}

###################################
# ROUTES FROM APP RTs TO TGW 
###################################

locals {
  tgw_routes = var.tgw_id == "" || length(var.dx_on_prem_cidrs) == 0 ? [] : flatten([
    for rt_id in var.route_table_ids : [
      for cidr in var.dx_on_prem_cidrs : {
        route_table_id = rt_id
        cidr_block     = cidr
      }
    ]
  ])
}

resource "aws_route" "tgw_routes" {
  for_each = {
    for r in local.tgw_routes :
    "${r.route_table_id}-${r.cidr_block}" => r
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.cidr_block
  transit_gateway_id     = var.tgw_id
}
