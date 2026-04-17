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
  auth_url    = "http://mycloud.lan:5000/v3" # Adjusted to HTTP based on earlier error
  insecure    = true                         # For self-signed lab certs
}
# 1. VAULT SECURITY GROUP
resource "openstack_networking_secgroup_v2" "vault_sg" {
  name        = "vault-sg"
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
  security_group_id = openstack_networking_secgroup_v2.vault_sg.id
}

# Rule: Allow SSH only from the Jump Box
resource "openstack_networking_secgroup_rule_v2" "allow_ssh_to_vault" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.jumpbox_sg.id
  security_group_id = openstack_networking_secgroup_v2.vault_sg.id
}

# 2. VAULT INSTANCE
resource "openstack_blockstorage_volume_v2" "vault_boot_vol" {
  name        = "vault-boot-disk"
  size        = 20 # 20GB is plenty for the OS + Vault's Raft DB
  image_id    = "PASTE_UBUNTU_IMAGE_ID_HERE"
  description = "Persistent boot disk for HashiCorp Vault"
}

resource "openstack_compute_instance_v2" "vault_server" {
  name            = "vault-server"
  flavor_name     = "m1.small"
  key_pair        = "k3s-cluster-key"
  security_groups = [openstack_networking_secgroup_v2.vault_sg.name]
  config_drive    = true

  # Attach the volume we created above as the boot device
  block_device {
    uuid                  = openstack_blockstorage_volume_v2.vault_boot_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false 
  }

  network {
    uuid        = openstack_networking_network_v2.mgmt_net.id
    fixed_ip_v4 = "10.10.10.50"
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - gpg
      - wget
    runcmd:
      # Simple hardening: disable root SSH
      - sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
      - systemctl restart ssh
    EOF
}