
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

# Allocate a Floating IP
resource "openstack_networking_floatingip_v2" "jumpbox_fip" {
  pool = "public" # Match your external network name
}

resource "openstack_blockstorage_volume_v3" "jumpbox_boot_vol" {
  name        = "jumpbox-boot-volume"
  size        = 20                  # Jumpbox usually needs more space for logs/binaries
  image_id    = var.image_uuid
  volume_type = "ncs-nvme"          # Switching to high-speed storage
}

data "openstack_networking_network_v2" "mgmt_private_net" {
  name = "mgmt_private_net"
}

# Create the Jump Box Instance
resource "openstack_compute_instance_v2" "jumpbox" {
  name            = "jumpbox"
  flavor_name     = "m1.micro"             # 1 vCPU / 512MB-1GB RAM is plenty
  config_drive    = true
  security_groups = ["jumpbox-sg"]

  network {
    uuid = data.openstack_networking_network_v2.mgmt_private_net.id
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.jumpbox_boot_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }


  user_data = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - git
      - curl
      - dnsutils
      - net-tools
      - ansible
      - python3-openstackclient
      - jq
      - unzip
    hostname: jumpbox
    users:
      - name: ubuntu
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
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