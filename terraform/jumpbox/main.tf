# resource "openstack_compute_keypair_v2" "management_key" {
#   name       = "root-cluster-key"
#   public_key = file("~/.ssh/id_ed25519_cluster.pub") # Path to your local public key
# }

# # 1. THE JUMPBOX
# resource "openstack_compute_instance_v2" "jumpbox" {
#   name            = "jumpbox"
#   image_name      = var.jumpbox_image
#   flavor_name     = var.jumpbox_flavour
#   key_pair        = openstack_compute_keypair_v2.management_key.name
#   security_groups = [openstack_networking_secgroup_v2.jumpbox_sg.name]

#   network { uuid = openstack_networking_network_v2.mgmt_net.id }
# }

# resource "openstack_networking_floatingip_v2" "fip_jump" { pool = "public" }
# resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
#   floating_ip = openstack_networking_floatingip_v2.fip_jump.address
#   instance_id = openstack_compute_instance_v2.jumpbox.id
# }

# output "jumpbox_ip" { value = openstack_networking_floatingip_v2.fip_jump.address }




# 1. Define the Security Group for the Jump Box
resource "openstack_networking_secgroup_v2" "jumpbox_sg" {
  name        = "jumpbox-secgroup"
  description = "Allow SSH from anywhere and internal management"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0" # Consider restricting this to your Home/Office IP
  security_group_id = openstack_networking_secgroup_v2.jumpbox_sg.id
}

# 2. Allocate a Floating IP
resource "openstack_networking_floatingip_v2" "jumpbox_fip" {
  pool = "public" # Match your external network name
}

# 3. Create the Jump Box Instance
resource "openstack_compute_instance_v2" "jumpbox" {
  name            = "jumpbox"
  image_name      = "Ubuntu-24.04-Minimal" # Use your verified image name/ID
  flavor_name     = "m1.tiny"             # 1 vCPU / 512MB-1GB RAM is plenty
  key_pair        = "k3s-cluster-key"
  config_drive    = true
  security_groups = [openstack_networking_secgroup_v2.jumpbox_sg.name]

  network {
    name = "private-net"
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - git
      - curl
      - dnsutils
      - net-tools
    hostname: jumpbox
    EOF
}

# 4. Attach the Floating IP
resource "openstack_compute_floatingip_associate_v2" "jumpbox_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.jumpbox_fip.address
  instance_id = openstack_compute_instance_v2.jumpbox.id
}

output "jumpbox_public_ip" {
  value = openstack_networking_floatingip_v2.jumpbox_fip.address
}