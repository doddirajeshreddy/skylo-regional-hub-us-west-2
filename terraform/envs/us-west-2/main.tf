# ------------------------------------
# NETWORK (VPC, subnets, IGW, NAT, RT)
# ------------------------------------
module "network" {
  source   = "../../modules/network"
  project  = var.project
  vpc_cidr = var.vpc_cidr
  azs      = var.azs
}

# ------------------------------------------------------
# TRANSIT GATEWAY ATTACHMENT 
# ------------------------------------------------------
module "tgw_attachment" {
  source = "../../modules/tgw_attachment"

  project          = var.project
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.private_app_subnet_ids
  tgw_id           = var.tgw_id
  route_table_ids  = module.network.private_app_route_table_ids
  dx_on_prem_cidrs = var.dx_on_prem_cidrs
}

# --------------------------------
# AWS MANAGED EKS
# --------------------------------
module "eks_cluster" {
  source     = "../../modules/eks_cluster"
  project    = var.project
  subnet_ids = module.network.private_app_subnet_ids
}
