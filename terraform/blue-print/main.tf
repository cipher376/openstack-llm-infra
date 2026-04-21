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

# This looks up the network that already exists
# data "openstack_networking_network_v2" "public_net" {
#   name = "public" 
#   # Or use: matching_metadata = "vlan_id:20"
# }



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

resource "openstack_networking_network_v2" "mgmt_net" {   name = var.mgmt_net }
resource "openstack_networking_subnet_v2" "mgmt_subnet" {
  network_id = openstack_networking_network_v2.mgmt_net.id
  cidr       = var.mgmt_net_range
  name       = "mgmt_subnet"
}

resource "openstack_networking_network_v2" "data_net" {   name = var.data_net }
resource "openstack_networking_subnet_v2" "data_subnet" {
  network_id = openstack_networking_network_v2.data_net.id
  cidr       = var.date_net_range
  name       = "data_subnet"

}

resource "openstack_networking_network_v2" "k3s_net" { name = var.service_net }
resource "openstack_networking_subnet_v2" "k3s_subnet" {
  network_id = openstack_networking_network_v2.k3s_net.id
  cidr       = var.service_net_range
  name       = "service_subnet"
}

resource "openstack_networking_network_v2" "service_net" { name = var.k3s_net }
resource "openstack_networking_subnet_v2" "service_subnet" {
  network_id = openstack_networking_network_v2.service_net.id
  cidr       = var.k3s_net_range
  name       = "k3s_subnet"
  
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

resource "openstack_networking_router_interface_v2" "service_itf" {
  router_id = openstack_networking_router_v2.vpc_router.id
  subnet_id = openstack_networking_subnet_v2.service_subnet.id
}



#===============================================================================
# --- DEFAULT KEY PAIR ---
#===============================================================================

resource "openstack_compute_keypair_v2" "cluster_keypair" {
  name       = "cluster-auth-key"
  public_key = file("${var.key_pair_file}")
}


#===============================================================================
# --- SECURITY GROUPS: THE FIREWALL TIERS ---
#===============================================================================
# bastion SG: Only SSH from your IP
resource "openstack_networking_secgroup_v2" "bastion_sg" { name = "bastion-sg" }


locals {
  bastion_rules = [
    { proto = "tcp",  min = 22, max = 22, remote_ip="172.16.0.0/16", desc = "ssh external" },
    { proto = "tcp",  min = 80, max = 80, remote_ip="0.0.0.0/0", desc = "External to ngix proxy http" },
    { proto = "tcp",  min = 443, max = 443, remote_ip="0.0.0.0/0", desc = "External to ngix proxy https" },
    { proto = "tcp",  min = 3128, max = 3128, remote_ip="10.10.0.0/16", desc = "internal to squid to external" },

  ]
}

resource "openstack_networking_secgroup_rule_v2" "bastion_sg_rules" {
  for_each = { for rule in local.bastion_rules : rule.desc => rule }

  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.bastion_sg.id
  
  protocol          = each.value.proto
  port_range_min    = each.value.min
  port_range_max    = each.value.max
  remote_ip_prefix  = each.value.remote_ip
}

#==================================================================================================================
#Gitlab security group 
#==================================================================================================================
resource "openstack_networking_secgroup_v2" "gitlab_sg" { name = "gitlab-sg" }
locals {
  gitlab_rules = [
    { proto = "tcp",  min = 80, max = 80, remote_ip="10.10.0.0/16", desc = "Allow bastion to access http traffic" },
    { proto = "tcp",  min = 443, max = 443, remote_ip="10.10.0.0/16", desc = "Allow bastion to access https traffic" },
  ]
}

resource "openstack_networking_secgroup_rule_v2" "gitlab_sg_rules" {
  for_each = { for rule in local.gitlab_rules : rule.desc => rule }

  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.gitlab_sg.id
  protocol          = each.value.proto
  port_range_min    = each.value.min
  port_range_max    = each.value.max
}


#==================================================================================
# Internal SG: Only allow SSH FROM the bastion
resource "openstack_networking_secgroup_v2" "internal_sg" { 
  name = "internal-sg"
  description = "Provide shared access to the vms e.g ssh from the jump box" 
  }
resource "openstack_networking_secgroup_rule_v2" "ssh_from_jump" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
  security_group_id = openstack_networking_secgroup_v2.internal_sg.id
}

#==========================================================================

# SeaweedFS S3 Port (8333) allowed from K3s and Data networks
resource "openstack_networking_secgroup_v2" "seaweedfs_sg" {
  name        = "seaweedfs-sg"
  description = "Security group for the the object storage (s3)"
}
resource "openstack_networking_secgroup_rule_v2" "s3_port" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8333
  port_range_max    = 8333
  remote_ip_prefix  = "10.10.0.0/16" # Covers all internal subnets
  security_group_id = openstack_networking_secgroup_v2.seaweedfs_sg.id
}

# Master Server Port (HTTP/gRPC)
resource "openstack_networking_secgroup_rule_v2" "master_port" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9333
  port_range_max    = 9333
  remote_ip_prefix  = "10.10.0.0/16" # Consider restricting to your VPC CIDR
  security_group_id = openstack_networking_secgroup_v2.seaweedfs_sg.id
}

# Volume Server Port
resource "openstack_networking_secgroup_rule_v2" "volume_port" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "10.10.0.0/16"
  security_group_id = openstack_networking_secgroup_v2.seaweedfs_sg.id
}

# Filer Port
resource "openstack_networking_secgroup_rule_v2" "filer_port" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8888
  port_range_max    = 8888
  remote_ip_prefix  = "10.10.0.0/16"
  security_group_id = openstack_networking_secgroup_v2.seaweedfs_sg.id
}

#==================================================================================================

# Security Group for Management Vault
resource "openstack_networking_secgroup_v2" "mgmt_vault_sg" {
  name        = "mgmt-vault-sg"
  description = "Security group for the Transit Auto-Unseal Vault"
}

# Allow SSH from bastion only
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


#============================================================================



# 1. VAULT SECURITY GROUP
resource "openstack_networking_secgroup_v2" "cluster_vault_sg" {
  name        = "cluster-vault-sg"
  description = "Security group for HashiCorp Vault"
}

# Rule: Allow Vault API (8200) from the internal subnets (Management, Data, K3s)
resource "openstack_networking_secgroup_rule_v2" "allow_vault_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8200
  port_range_max    = 8200
  remote_ip_prefix  = "10.0.0.0/16" # Allows all our 10.x.x.x tiers
  security_group_id = openstack_networking_secgroup_v2.cluster_vault_sg.id
}

# Rule: Allow SSH only from the Jump Box
resource "openstack_networking_secgroup_rule_v2" "allow_ssh_to_vault" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
  security_group_id = openstack_networking_secgroup_v2.cluster_vault_sg.id
}

#==============================================================================
# KUBERNETES
#==============================================================================
# 1. Create the Security Group
resource "openstack_networking_secgroup_v2" "k3s_internal" {
  name        = "k3s-internal-sg"
  description = "Internal cluster communication for Cilium and K3s"
}

# 2. Define the rule set in a local variable for readability
locals {
  k3s_rules = [
    { proto = "udp",  min = 8472, max = 8472, desc = "VXLAN Overlay" },
    { proto = "tcp",  min = 4240, max = 4240, desc = "Cilium Health" },
    { proto = "tcp",  min = 6443, max = 6443, desc = "K3s API" },
    { proto = "tcp",  min = 2379, max = 2380, desc = "etcd HA" },
    { proto = "tcp",  min = 10250, max = 10250, desc = "kubectl logs" },
  ]
}

# 3. Iterate through the list to create the rules
resource "openstack_networking_secgroup_rule_v2" "k3s_internal_rules" {
  for_each = { for rule in local.k3s_rules : rule.desc => rule }

  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k3s_internal.id
  
  protocol          = each.value.proto
  port_range_min    = each.value.min
  port_range_max    = each.value.max
  remote_ip_prefix  = "10.10.30.0/24" 
}

