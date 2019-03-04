# Configure the OpenStack Provider
provider "openstack" {
  auth_url         = "${var.openstack_auth_url}"
  password         = "${var.openstack_password}"
  tenant_name      = "${var.openstack_tenant_name}"
  user_name        = "${var.openstack_user_name}"
  user_domain_name = "${var.openstack_user_domain_name}"
}

# Create Keypair
resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.prefix}-keypair"
  public_key = "${file(var.openstack_keypair_public_key)}"
}

# Create Security Group
resource "openstack_networking_secgroup_v2" "secgroup" {
  name        = "${var.prefix}-secgroup"
  description = "Security Group for ${var.prefix}"
}

# Add rule to Security Group
resource "openstack_networking_secgroup_rule_v2" "secgroup_rule" {
  ethertype         = "IPv4"
  direction         = "ingress"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

# Get info about external network
data "openstack_networking_network_v2" "external_network" {
  name = "${var.openstack_networking_network_external_network_name}"
}

# Create private network
resource "openstack_networking_network_v2" "private-network" {
  count          = "${var.environment_count}"
  name           = "${format("%s-%02d-private-network", var.prefix, count.index + 1)}"
  admin_state_up = "true"
}

# Create private subnet
resource "openstack_networking_subnet_v2" "private-subnet" {
  count           = "${var.environment_count}"
  name            = "${format("%s-%02d-private-subnet", var.prefix, count.index + 1)}"
  network_id      = "${element(openstack_networking_network_v2.private-network.*.id, count.index)}"
  cidr            = "${var.openstack_networking_subnet_cidr}"
  dns_nameservers = "${var.openstack_networking_subnet_dns_nameservers}"
}

# Create router for private subnet
resource "openstack_networking_router_v2" "private-router" {
  count               = "${var.environment_count}"
  name                = "${format("%s-%02d-private-router", var.prefix, count.index + 1)}"
  admin_state_up      = "true"
  external_network_id = "${data.openstack_networking_network_v2.external_network.id}"
}

# Create router interface for private subnet
resource "openstack_networking_router_interface_v2" "router-interface" {
  count      = "${var.environment_count}"
  router_id  = "${element(openstack_networking_router_v2.private-router.*.id, count.index)}"
  subnet_id  = "${element(openstack_networking_subnet_v2.private-subnet.*.id, count.index)}"
}

# Create floating IP for nodes
resource "openstack_networking_floatingip_v2" "floatingip" {
  count = "${var.vm_nodes * var.environment_count}"
  pool  = "${var.openstack_networking_floatingip}"
}

# Create nodes
resource "openstack_compute_instance_v2" "vms" {
  count             = "${var.vm_nodes * var.environment_count}"
  name              = "${format("%s-node%02d.%02d.%s", var.prefix, count.index % var.vm_nodes + 1, count.index / var.vm_nodes + 1, var.domain)}"
  availability_zone = "${var.openstack_availability_zone}"
  image_name        = "${var.openstack_instance_image_name}"
  flavor_name       = "${var.openstack_instance_flavor_name}"
  key_pair          = "${openstack_compute_keypair_v2.keypair.name}"
  security_groups   = ["${openstack_networking_secgroup_v2.secgroup.name}"]

  network {
    uuid           = "${element(openstack_networking_network_v2.private-network.*.id, count.index / var.vm_nodes )}"
    fixed_ip_v4    = "${cidrhost(var.openstack_networking_subnet_cidr, var.vm_nodes_network_private_ip_last_octet + count.index % var.vm_nodes + 1)}"
    access_network = true
  }
}

# Associate floating IP with nodes
resource "openstack_compute_floatingip_associate_v2" "floatingip-associate" {
  count       = "${var.vm_nodes * var.environment_count}"
  floating_ip = "${element(openstack_networking_floatingip_v2.floatingip.*.address, count.index)}"
  instance_id = "${element(openstack_compute_instance_v2.vms.*.id, count.index)}"
}

# Wait for VMs to be fully up (accessible by ssh)
resource "null_resource" "vms" {
  count             = "${var.vm_nodes * var.environment_count}"
  depends_on        = ["openstack_compute_floatingip_associate_v2.floatingip-associate"]

  connection {
    type = "ssh"
    host = "${element(openstack_networking_floatingip_v2.floatingip.*.address, count.index)}"
    #private_key = "${file("~/.ssh/id_rsa")}"
    user = "${var.username}"
    agent = true
  }
  provisioner "remote-exec" {
    inline = [ ]
  }
}

output "vms_name" {
  value = "${openstack_compute_instance_v2.vms.*.name}"
}

output "vms_public_ip" {
  description = "The public IP address for VMs"
  value       = "${openstack_networking_floatingip_v2.floatingip.*.address}"
}
