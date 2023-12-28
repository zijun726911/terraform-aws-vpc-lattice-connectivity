provider "aws" {
  alias  = "prod"
  region = "us-west-2"
}

provider "aws" {
  alias  = "lattice_beta"
  region = "us-west-2"
  endpoints {
#    vpclattice = <vpc lattice beta endpoint>
  }
}


#module "minimal_connectivity_beta" {
#  source      = "./modules/minimal_connectivity_module"
#  name_suffix = "-beta"
#  providers   = {
#    aws = aws.lattice_beta
#  }
#}

module "minimal_connectivity_prod" {
  source      = "./modules/minimal_connectivity_module"
  name_suffix = "-prod"
  providers   = {
    aws = aws.prod
  }
}

#output "lattice_service_dns_name_beta" {
#  value = module.minimal_connectivity_beta.lattice_service_dns_name
#}
#
#output "client_instance_id_beta" {
#  value = module.minimal_connectivity_beta.client_instance_id
#}
#
#output "target_instance_id_beta" {
#  value = module.minimal_connectivity_beta.target_instance_id
#}

output "lattice_service_dns_name_prod" {
  value = module.minimal_connectivity_prod.lattice_service_dns_name
}

output "client_instance_id_prod" {
  value = module.minimal_connectivity_prod.client_instance_id
}

output "target_instance_id_prod" {
  value = module.minimal_connectivity_prod.target_instance_id
}