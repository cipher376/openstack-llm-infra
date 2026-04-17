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

# Persistent Storage for Raft (Tiny but critical)
resource "openstack_blockstorage_volume_v3" "mgmt_vault_vol" {
  name = "mgmt-vault-data"
  size = 10 
  image_id = var.image_uuid
  volume_type = "ncs-nvme"
}

# The Management Vault Instance
resource "openstack_compute_instance_v2" "mgmt_vault" {
  name            = "mgmt-vault-transit"
  flavor_name     = "m1.micro" # Low resource footprint
  security_groups = [var.mgmt_vault_sg]
  config_drive    = true


  network {
    name        = var.mgmt_net
    fixed_ip_v4 = var.vm_ipv4 # Fixed IP for predictable unseal config
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.mgmt_vault_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
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