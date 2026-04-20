terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  auth_url    = "${var.auth_url}"
  region      = "${var.region}"
  # Authentication is typically handled via environment variables 
  # (OS_USERNAME, OS_PASSWORD, etc.) for security.
}

resource "openstack_blockstorage_volume_v3" "model_storage" {
  name          = "model-registry-1tb"
  volume_type   = "ncs-hdd"
  size          = 1000
}

resource "openstack_compute_instance_v2" "seaweedfs" {
  name            = "seaweedfs-storage"
  flavor_name     = "m1.medium" # Focused on I/O, 4GB RAM is fine
  security_groups = ["internal-sg","seaweedfs-sg"]
  config_drive    = true

  network { 
    name = "data_private_net"
    fixed_ip_v4 = var.seaweedfs_vm_ipv4 
   }

  # OS Disk
  block_device {
    uuid                  = var.image_UUId
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 30
    boot_index            = 0
    delete_on_termination = true
    volume_type           = "ncs-nvme"
  }

  # Attached 1TB Data Disk
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.model_storage.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = -1
    delete_on_termination = false
  }

  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${file(var.ssh_public_key)}
    hostname: seaweedfs
    runcmd:
      - mkfs.ext4 /dev/vdb
      - mkdir -p /data/models
      - mount /dev/vdb /data/models
      - echo "/dev/vdb /data/models ext4 defaults 0 0" >> /etc/fstab
      - fallocate -l 8G /swapfile
      - chmod 600 /swapfile
      - mkswap /swapfile
      - swapon /swapfile
      - echo '/swapfile none swap sw 0 0' >> /etc/fstab
    EOF
}