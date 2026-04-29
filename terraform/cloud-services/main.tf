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



resource "openstack_blockstorage_volume_v3" "cloud_services_boot_vol" {
  name        = "cloud-services-boot-disk"
  size        = 30 
  image_id    = var.image_uuid
  description = "Persistent boot disk for cloud-services"
  volume_type = "ncs-nvme"
}


resource "openstack_compute_instance_v2" "cloud_services" {
  name            = "cloud-services"
  flavor_name     = "m1.small" # Recommended 2GB+ RAM for multiple services
  security_groups = ["cloud-services-sg"]
  key_pair        = var.key_pair

  network {
    name = var.subnet
    fixed_ip_v4 = var.vm_ipv4
  }
  
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.cloud_services_boot_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false 
  }

  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    EOF

}