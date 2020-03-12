data "aws_availability_zones" "available" {}

module "vpc" {
  source                           = "terraform-aws-modules/vpc/aws"
  version                          = "2.5.0"
  name                             = "${var.namespace}-vpc"
  cidr                             = "10.0.0.0/16"
  azs                              = data.aws_availability_zones.available.names

  public_subnets                   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets                  = ["10.0.3.0/24", "10.0.4.0/24"]
  database_subnets                 = ["10.0.5.0/24", "10.0.6.0/24"]

  assign_generated_ipv6_cidr_block = true
  create_database_subnet_group     = true
  enable_nat_gateway               = true
  single_nat_gateway               = true
  enable_dns_hostnames = true
  enable_dns_support   = true

}


module "bastionhost_sg" {
  source = "scottwinkler/sg/aws"
  description = "Security group for Bastion Host with SSH ports open within VPC"
  name   = "${var.namespace}-bh_sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      port            = 22
      cidr_blocks = ["24.46.252.51/32"]
    },
  ]
}

module "lb_sg" {
  source = "scottwinkler/sg/aws"
  description = "Security group for load balancer with HTTP ports open within VPC"
  name   = "${var.namespace}-lb_sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      port            = 80
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]
}


module "webserver_sg" {
  source = "scottwinkler/sg/aws"
  description = "Security group for web-server with HTTP and SSH ports open within VPC"
  name   = "${var.namespace}-webserver_sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      port            = 80
      security_groups = [module.lb_sg.security_group.id]
    },
    {
      port       = 22
      security_groups = [module.bastionhost_sg.security_group.id]
    }
  ]
}

module "db_sg" {
  source = "scottwinkler/sg/aws"
  description = "Security group for database ports open within VPC"
  name   = "${var.namespace}-db_sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [{
    port            = 3306
    security_groups = [module.webserver_sg.security_group.id]
  }]
}
