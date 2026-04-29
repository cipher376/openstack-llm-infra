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

#======================================================================================
#  cloud services
#======================================================================================
resource "openstack_networking_secgroup_v2" "cloud_services_sg" {
  name        = "cloud-services-sg"
  description = "Security group for Pi-hole, WireGuard, and Uptime Kuma"
}


# SSH Access
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
  security_group_id = openstack_networking_secgroup_v2.cloud_services_sg.id
}

# DNS (Pi-hole)
resource "openstack_networking_secgroup_rule_v2" "dns_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.cloud_services_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "dns_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
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
  for_each          = toset(["80", "443", "3001"])
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = var.internal_network
  security_group_id = openstack_networking_secgroup_v2.cloud_services_sg.id
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
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
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
  remote_group_id  = openstack_networking_secgroup_v2.cluster_vault_sg.id
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
  count             = 2
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8200 + count.index
  port_range_max    = 8200 + count.index
  remote_ip_prefix  = "10.10.0.0/16" # Allows all our 10.10.x.x tiers
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
    { proto = "tcp",  min = 80, max = 80, desc = "http clilium gateway" },
    { proto = "tcp",  min = 443, max = 443, desc = "https clilium gateway" },
    { proto = "tcp",  min = 179, max = 179, desc = "Router bgp peer port" }
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
  remote_ip_prefix  = "10.10.0.0/16" 
}

resource "openstack_networking_secgroup_rule_v2" "Allow_cloud_services_k3s_tcp" {
  for_each          = toset(["udp", "tcp", "icmp"])
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value
  remote_group_id   = openstack_networking_secgroup_v2.cloud_services_sg.id
  security_group_id = openstack_networking_secgroup_v2.k3s_internal.id
}
resource "openstack_networking_secgroup_rule_v2" "Allow_cloud_services_k3s_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
  security_group_id = openstack_networking_secgroup_v2.k3s_internal.id
}

