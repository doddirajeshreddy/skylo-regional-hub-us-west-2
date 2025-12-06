# Example values for the us-west-2 regional hub environment.

project  = "skylo-regional-hub"
vpc_cidr = "10.20.0.0/16"
azs      = ["us-west-2a", "us-west-2b", "us-west-2c"]

# If you do not yet know the TGW ID, leave this as empty.
tgw_id = ""

# If you do not yet know ground-station CIDRs, leave this empty list.
dx_on_prem_cidrs = []
