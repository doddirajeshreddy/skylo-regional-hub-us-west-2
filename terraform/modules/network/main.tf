###################################
# VPC
###################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

###################################
# INTERNET GATEWAY
###################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-igw"
  }
}

###################################
# SUBNETS
###################################

# Public subnets (for NAT Gateways)
resource "aws_subnet" "public" {
  for_each = toset(var.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, index(var.azs, each.key))
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-${each.key}"
    Tier = "public"
  }
}

# Private-App subnets (EKS nodes + internal NLB)
resource "aws_subnet" "private_app" {
  for_each = toset(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10 + index(var.azs, each.key))
  availability_zone = each.key

  tags = {
    Name = "${var.project}-private-app-${each.key}"
    Tier = "private-app"
  }
}

# Private-Data subnets (Redis / databases)
resource "aws_subnet" "private_data" {
  for_each = toset(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20 + index(var.azs, each.key))
  availability_zone = each.key

  tags = {
    Name = "${var.project}-private-data-${each.key}"
    Tier = "private-data"
  }
}

###################################
# NAT GATEWAYS (one per AZ)
###################################

resource "aws_eip" "nat" {
  for_each = aws_subnet.public

  vpc = true

  tags = {
    Name = "${var.project}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name = "${var.project}-nat-${each.key}"
  }
}

###################################
# ROUTE TABLES
###################################

# Public route table (Internet via IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public

  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

# Private-App route tables (per AZ) with NAT egress
resource "aws_route_table" "private_app" {
  for_each = aws_subnet.private_app

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-private-app-rt-${each.key}"
  }
}

resource "aws_route" "private_app_default" {
  for_each = aws_route_table.private_app

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private_app_assoc" {
  for_each = aws_subnet.private_app

  route_table_id = aws_route_table.private_app[each.key].id
  subnet_id      = each.value.id
}

# Private-Data route tables (no default Internet route)
resource "aws_route_table" "private_data" {
  for_each = aws_subnet.private_data

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-private-data-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private_data_assoc" {
  for_each = aws_subnet.private_data

  route_table_id = aws_route_table.private_data[each.key].id
  subnet_id      = each.value.id
}
