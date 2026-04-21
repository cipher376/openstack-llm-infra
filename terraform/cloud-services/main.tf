terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  auth_url    = var.auth_url
  region      = "${var.region}"
  # Authentication is typically handled via environment variables 
  # (OS_USERNAME, OS_PASSWORD, etc.) for security.
}

resource "openstack_networking_secgroup_v2" "cloud_services_sg" {
  name        = "cloud-services-secgroup"
  description = "Security group for Pi-hole, WireGuard, and Uptime Kuma"
}

# SSH Access
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.internal_network
  security_group_id = openstack_networking_secgroup_v2.cloud_services_sg.id
}

# DNS (Pi-hole)
resource "openstack_networking_secgroup_rule_v2" "dns_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = var.internal_network
  security_group_id = openstack_networking_secgroup_v2.cloud_services_sg.id
}

# WireGuard VPN (UDP)
resource "openstack_networking_secgroup_rule_v2" "wireguard" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 51820
  port_range_max    = 51820
  remote_ip_prefix  = var.internal_network
  security_group_id = openstack_networking_secgroup_v2.cloud_services_sg.id
}

# Web UI Access (Pi-hole: 80, Uptime Kuma: 3001)
# Note: You can consolidate these or restrict them to VPN range later
resource "openstack_networking_secgroup_rule_v2" "web_uis" {
  for_each          = toset(["80", "3001"])
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = var.internal_network
  security_group_id = openstack_networking_secgroup_v2.cloud_services_sg.id
}

resource "openstack_blockstorage_volume_v3" "cloud_services_boot_vol" {
  name        = "cloud-services-boot-disk"
  size        = 30 
  image_id    = var.image_uuid
  description = "Persistent boot disk for cloud-services"
  volume_type = "ncs-nvme"
}

resource "openstack_compute_instance_v2" "cloud_services" {
  name            = "cloud-services"
  flavor_name     = "m1.small" # Recommended 2GB+ RAM for multiple services
  security_groups = [openstack_networking_secgroup_v2.cloud_services_sg.name]
  key_pair        = var.key_pair

  network {
    name = var.subnet
    fixed_ip_v4 = var.vm_ipv4
  }
  
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.cloud_services_boot_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false 
  }

  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    EOF

}