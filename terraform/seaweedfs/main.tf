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

resource "openstack_blockstorage_volume_v2" "model_storage" {
  name = "model-registry-1tb"
  size = 1000
}

resource "openstack_compute_instance_v2" "seaweedfs" {
  name            = "seaweedfs-storage"
  flavor_name     = "m1.medium" # Focused on I/O, 4GB RAM is fine
  key_pair        = "k3s-cluster-key"
  security_groups = [openstack_networking_secgroup_v2.internal_sg.name]
  config_drive    = true

  network { 
    uuid = openstack_networking_network_v2.data_net.id
    fixed_ip_v4 = "10.0.1.20" 
   }

  # OS Disk
  block_device {
    uuid                  = var.image_UUId
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 30
    boot_index            = 0
    delete_on_termination = true
  }

  # Attached 1TB Data Disk
  block_device {
    uuid                  = openstack_blockstorage_volume_v2.model_storage.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = -1
    delete_on_termination = false
  }

  user_data = <<-EOF
    #cloud-config
    runcmd:
      - mkfs.ext4 /dev/vdb
      - mkdir -p /data/models
      - mount /dev/vdb /data/models
      - echo "/dev/vdb /data/models ext4 defaults 0 0" >> /etc/fstab
    EOF
}