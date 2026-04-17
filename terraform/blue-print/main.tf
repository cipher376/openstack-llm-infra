# --- PROVIDER CONFIGURATION ---
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  auth_url    = var.auth_url # Adjusted to HTTP based on earlier error
  insecure    = true                         # For self-signed lab certs
}


# The External (Public) Network
# This is usually a 'flat' or 'vlan' network that connects to the outside world.
resource "openstack_networking_network_v2" "public_net" {
  name           = "public"
  admin_state_up = "true"
  external       = "true" # CRITICAL: This marks the network as a gateway source
  shared         = "true"
  # Provider physical mapping
  # 'segments' defines the L2 properties
  segments {
    network_type     = "vlan"
    physical_network = "physnet1" # This name must match your Neutron configuration (e.g., in ml2_conf.ini)
    segmentation_id  = 20         # Your VLAN ID
  }
}

# 2. The Public Subnet
# This defines the pool of Floating IPs (172.16.20.0/25 as you specified)
resource "openstack_networking_subnet_v2" "public_subnet" {
  name            = "public_subnet"
  network_id      = openstack_networking_network_v2.public_net.id
  cidr            = "172.16.20.0/24"
  gateway_ip      = "172.16.20.1" # The upstream physical router IP
  allocation_pool {
    start = "172.16.20.5"
    end   = "172.16.20.120"
  }
  enable_dhcp     = false # Usually false for external networks
  dns_nameservers = ["172.16.20.1", "8.8.8.8", "1.1.1.1"]
}

# 3. The Public Gateway (Router)
# This is the "VPC Router" that bridges your private networks to the public one.
resource "openstack_networking_router_v2" "vpc_router" {
  name                = "vpc_router"
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.public_net.id
}


# --- NETWORKING: 3-TIER TOPOLOGY ---

resource "openstack_networking_network_v2" "mgmt_net" { name = "mgmt_private_net" }
resource "openstack_networking_subnet_v2" "mgmt_subnet" {
  network_id = openstack_networking_network_v2.mgmt_net.id
  cidr       = "10.10.10.0/24"
}

resource "openstack_networking_network_v2" "data_net" { name = "data_private_net" }
resource "openstack_networking_subnet_v2" "data_subnet" {
  network_id = openstack_networking_network_v2.data_net.id
  cidr       = "10.10.20.0/24"
}

resource "openstack_networking_network_v2" "k3s_net" { name = "k3s_private_net" }
resource "openstack_networking_subnet_v2" "k3s_subnet" {
  network_id = openstack_networking_network_v2.k3s_net.id
  cidr       = "10.10.30.0/24"
}


resource "openstack_networking_router_interface_v2" "mgmt_itf" {
  router_id = openstack_networking_router_v2.vpc_router.id
  subnet_id = openstack_networking_subnet_v2.mgmt_subnet.id
}

resource "openstack_networking_router_interface_v2" "data_itf" {
  router_id = openstack_networking_router_v2.vpc_router.id
  subnet_id = openstack_networking_subnet_v2.data_subnet.id
}

resource "openstack_networking_router_interface_v2" "k3s_itf" {
  router_id = openstack_networking_router_v2.vpc_router.id
  subnet_id = openstack_networking_subnet_v2.k3s_subnet.id
}

# --- SECURITY GROUPS: THE FIREWALL TIERS ---

# Jumpbox SG: Only SSH from your IP
resource "openstack_networking_secgroup_v2" "jumpbox_sg" { name = "jumpbox-sg" }
resource "openstack_networking_secgroup_rule_v2" "ssh_ext" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "172.16.0.0/16" # CHANGE TO YOUR HOME IP
  security_group_id = openstack_networking_secgroup_v2.jumpbox_sg.id
}

# Internal SG: Only allow SSH FROM the Jumpbox
resource "openstack_networking_secgroup_v2" "internal_sg" { name = "internal-sg" }
resource "openstack_networking_secgroup_rule_v2" "ssh_from_jump" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.jumpbox_sg.id
  security_group_id = openstack_networking_secgroup_v2.internal_sg.id
}



# SeaweedFS S3 Port (8333) allowed from K3s and Data networks
resource "openstack_networking_secgroup_rule_v2" "seaweed_s3" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8333
  port_range_max    = 8333
  remote_ip_prefix  = "10.0.0.0/16" # Covers all internal subnets
  security_group_id = openstack_networking_secgroup_v2.internal_sg.id
}


# Security Group for Management Vault
resource "openstack_networking_secgroup_v2" "mgmt_vault_sg" {
  name        = "mgmt-vault-sg"
  description = "Security group for the Transit Auto-Unseal Vault"
}

# Allow SSH from Jumpbox only
resource "openstack_networking_secgroup_rule_v2" "mgmt_vault_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "10.10.10.0/24" # Management Subnet
  security_group_id = openstack_networking_secgroup_v2.mgmt_vault_sg.id
}

# Allow Vault API (8200) and Cluster (8201) traffic
resource "openstack_networking_secgroup_rule_v2" "mgmt_vault_api" {
  count             = 2
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8200 + count.index
  port_range_max    = 8200 + count.index
  remote_ip_prefix  = "10.0.0.0/8" # Internal network range
  security_group_id = openstack_networking_secgroup_v2.mgmt_vault_sg.id
}