variable "environment_count" {
  default = 1
}

variable "openstack_auth_url" {
  description = "The endpoint url to connect to OpenStack"
}

variable "openstack_instance_flavor_name" {
  description = "Name of flavor in OpenStack"
}

variable "openstack_instance_image_name" {
  description = "Image name for VMs in OpenStack"
}

variable "openstack_keypair_public_key" {
  description = "SSH Public key location"
  default = "~/.ssh/id_rsa.pub"
}

variable "openstack_networking_network_external_network_name" {
  description = "External network name"
  default = "public"
}

variable "openstack_networking_subnet_cidr" {
  description = "CIDR for new network where all VMs will be connected"
  default = "192.168.250.0/24"
}

variable "openstack_networking_subnet_dns_nameservers" {
  description = "DNS servers"
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "openstack_networking_floatingip" {
  default = "public"
}

variable "openstack_password" {
  description = "The password for the tenant"
}

variable "openstack_tenant_name" {
  description = "The name of the tenant"
}

variable "openstack_user_domain_name" {
  description = "The name of the domain"
}

variable "openstack_user_name" {
  description = "The username for the tenant"
}

variable "domain" {
  default = "localdomain"
}

variable "prefix" {
  description = "Prefix used for all names"
  default     = "k8s-istio-demo"
}

variable "username" {
  description = "Username which will be used for connecting to VM"
  default     = "ubuntu"
}

variable "vm_nodes" {
  description = "Number of VMs which should be created as nodes"
  default     = 3
}

variable "vm_nodes_network_private_ip_last_octet" {
  description = "Last octet of VMs inside cloud_network (node01: 192.168.250.11, node02: 192.168.250.12, node03: 192.168.250.13 )"
  default     = 10
}
