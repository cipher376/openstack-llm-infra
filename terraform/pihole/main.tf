terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

# 1. Security Group for DNS and Web UI
resource "openstack_networking_secgroup_v2" "pihole_sg" {
  name        = "pihole-secgroup"
  description = "Security group for Pi-hole DNS and Admin UI"
}

resource "openstack_networking_secgroup_rule_v2" "dns_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.pihole_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "dns_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.pihole_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "http_admin" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0" # Consider restricting to your local IP
  security_group_id = openstack_networking_secgroup_v2.pihole_sg.id
}

# 2. Deploy the Pi-hole Container using Zun
resource "openstack_container_container_v1" "pihole" {
  name       = "pihole-dns"
  image      = "pihole/pihole:latest"
  cpu        = 1
  memory     = 512
  command    = [] # Uses the default entrypoint
  
  # Network Configuration
  nets {
    network = "service-net" 
  }

  # Environment Variables
  environment = {
    TZ           = "America/Edmonton"
    WEBPASSWORD  = var.admin_pass
  }

  security_groups = [openstack_networking_secgroup_v2.pihole_sg.name]
  
  restart_policy = {
    name = "always"
  }
}

# 3. Output the Internal IP
output "pihole_internal_ip" {
  value = openstack_container_container_v1.pihole.addresses
}