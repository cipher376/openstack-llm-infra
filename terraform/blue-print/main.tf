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
  name           = var.public_net_name
  admin_state_up = "true"
  external       = "true" # CRITICAL: This marks the network as a gateway source
  shared         = "true"
  # Provider physical mapping
  # 'segments' defines the L2 properties
  segments {
    network_type     = var.public_network_type
    physical_network = var.public_interface_name # This name must match your Neutron configuration (e.g., in ml2_conf.ini)
    segmentation_id  = var.vlan_id        # Your VLAN ID
  }
}




# 2. The Public Subnet
# This defines the pool of Floating IPs (172.16.20.0/25 as you specified)
resource "openstack_networking_subnet_v2" "public_subnet" {
  name            = var.public_subnet_name
  network_id      = openstack_networking_network_v2.public_net.id
  cidr            = var.public_cidr
  gateway_ip      = var.physical_router_gateway_ip# The upstream physical router IP
  allocation_pool {
    start = var.public_allocation_pool_start
    end   = var.public_allocation_pool_end
  }
  enable_dhcp     = false # Usually false for external networks
  dns_nameservers = ["8.8.8.8", "1.1.1.1", "8.8.4.4", "1.0.0.1"]
}


resource "openstack_networking_router_v2" "vpc_router_01" {
  name                = var.vpc_router_01_name
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.public_net.id
}


# --- NETWORKING: 3-TIER TOPOLOGY ---

resource "openstack_networking_network_v2" "mgmt_net" {   name = var.mgmt_net }
resource "openstack_networking_subnet_v2" "mgmt_subnet" {
  network_id = openstack_networking_network_v2.mgmt_net.id
  cidr       = var.mgmt_net_range
  name       = var.mgmt_subnet_net_name
}

resource "openstack_networking_network_v2" "data_net" {   name = var.data_net }
resource "openstack_networking_subnet_v2" "data_subnet" {
  network_id = openstack_networking_network_v2.data_net.id
  cidr       = var.data_net_range
  name       = var.data_subnet_net_name

}

resource "openstack_networking_network_v2" "k3s_net" { name = var.k3s_net }
resource "openstack_networking_subnet_v2" "k3s_subnet" {
  network_id = openstack_networking_network_v2.k3s_net.id
  cidr       = var.k3s_net_range
  name       = var.k3s_subnet_net_name
}


resource "openstack_networking_network_v2" "service_net" { name = var.service_net }
resource "openstack_networking_subnet_v2" "service_subnet" {
  network_id = openstack_networking_network_v2.service_net.id
  cidr       = var.service_net_range
  name       = var.service_subnet_net_name
}


resource "openstack_networking_router_interface_v2" "mgmt_itf" {
  router_id = openstack_networking_router_v2.vpc_router_01.id
  subnet_id = openstack_networking_subnet_v2.mgmt_subnet.id
}

resource "openstack_networking_router_interface_v2" "data_itf" {
  router_id = openstack_networking_router_v2.vpc_router_01.id
  subnet_id = openstack_networking_subnet_v2.data_subnet.id
}

resource "openstack_networking_router_interface_v2" "k3s_itf" {
  router_id = openstack_networking_router_v2.vpc_router_01.id
  subnet_id = openstack_networking_subnet_v2.k3s_subnet.id
}

resource "openstack_networking_router_interface_v2" "service_itf" {
  router_id = openstack_networking_router_v2.vpc_router_01.id
  subnet_id = openstack_networking_subnet_v2.service_subnet.id
}



#===============================================================================
# --- DEFAULT KEY PAIR ---
#===============================================================================

resource "openstack_compute_keypair_v2" "cluster_keypair" {
  name       = var.cluster-auth-key
  public_key = file("${var.key_pair_file}")
}

