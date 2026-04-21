
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
resource "openstack_networking_floatingip_v2" "bastion_fip" {
  pool = "public" # Match your external network name
}

resource "openstack_blockstorage_volume_v3" "bastion_boot_vol" {
  name        = "bastion-boot-volume"
  size        = 20                  # bastion usually needs more space for logs/binaries
  image_id    = var.image_uuid
  volume_type = "ncs-nvme"          # Switching to high-speed storage
}

data "openstack_networking_network_v2" "mgmt_private_net" {
  name = "mgmt_private_net"
}

# Create the Jump Box Instance
resource "openstack_compute_instance_v2" "bastion" {
  name            = "bastion-server"
  flavor_name     = "m1.small"             
  config_drive    = true
  security_groups = ["bastion-sg"]
  key_pair        = var.key_pair


  network {
    uuid = data.openstack_networking_network_v2.mgmt_private_net.id
    fixed_ip_v4 = var.bastion_ipv4
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.bastion_boot_vol.id
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
    hostname: bastion-server
    users:
      - name: ubuntu
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    write_files:
      - path: /etc/netplan/99-custom-dns.yaml
        content: |
          network:
            version: 2
            ethernets:
              ens3:
                dhcp4: true
                dhcp4-overrides:
                  use-dns: false
                nameservers:
                  addresses: [${var.cloud_service_vm_IPv4}] 
    runcmd:
      - fallocate -l 4G /swapfile
      - chmod 600 /swapfile
      - mkswap /swapfile
      - swapon /swapfile
      - echo '/swapfile none swap sw 0 0' >> /etc/fstab
    EOF



}
# 4. Attach the Floating IP
resource "openstack_compute_floatingip_associate_v2" "bastion_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
  instance_id = openstack_compute_instance_v2.bastion.id
}

output "bastion_public_ip" {
  value = openstack_networking_floatingip_v2.bastion_fip.address
}