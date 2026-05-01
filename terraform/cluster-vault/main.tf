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
  region      = var.region

}


# 2. VAULT INSTANCE
resource "openstack_blockstorage_volume_v3" "cluster_vault_boot_vol" {
  name        = "cluster-vault-boot-disk"
  size        = 15 # 20GB is plenty for the OS + Vault's Raft DB
  image_id    = var.image_uuid
  description = "Persistent boot disk for cluster Vault"
  volume_type = "ncs-nvme"
}

resource "openstack_compute_instance_v2" "cluster_vault" {
  name            = "cluster-vault"
  flavor_name     = "m1.mini"
  security_groups = ["cluster-vault-sg"]
  config_drive    = true

  # Attach the volume we created above as the boot device
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.cluster_vault_boot_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false 
  }

  network {
    name        =  "service_private_net"
    fixed_ip_v4 = var.vm_ipv4
  }

  user_data = <<-EOF
    #cloud-config
    packages:
      - gpg
      - wget
    runcmd:
      # Install Vault binary
      - wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
      - apt-get update && apt-get install vault -y
      
      # Prepare Raft directories
      - mkdir -p /opt/vault/data
      - chown -R vault:vault /opt/vault/data
    users:
      - name: ubuntu
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    EOF
}