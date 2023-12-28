output "lattice_service_dns_name" {
  value = module.lattice_resources.services.my_lattice_svc.attributes.dns_entry[0].domain_name
}

output "client_instance_id" {
  value = module.client_instance.id
}

output "target_instance_id" {
  value = module.target_instance.id
}