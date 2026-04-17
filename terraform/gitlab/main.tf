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

# ------------------------------------------------------------------ #
#  GitLab Cloud-Init (User Data)                                     #
# ------------------------------------------------------------------ #

locals {
  gitlab_user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${var.ssh_public_key}
    hostname: gitlab-server
    runcmd:
      - fallocate -l 8G /swapfile
      - chmod 600 /swapfile
      - mkswap /swapfile
      - swapon /swapfile
      - echo '/swapfile none swap sw 0 0' >> /etc/fstab
    EOF
}

# ------------------------------------------------------------------ #
#  VM — GitLab Server                                                #
# ------------------------------------------------------------------ #

resource "openstack_compute_instance_v2" "gitlab_server" {
  name            = "gitlab-server"
  flavor_name     = "standard.large"             # Equivalent to your 4-core / 8GB RAM
  key_pair        = "${var.key_pair}"           # Pre-registered OpenStack keypair
  security_groups = [openstack_networking_secgroup_v2.internal_sg.name]
  user_data       = local.gitlab_user_data
  config_drive    = true

  network {
    uuid = openstack_networking_network_v2.data_net.id
    fixed_ip_v4 = "${var.gitlab_vm_ipv4}"
  }

  # Primary Disk (OS) - Often defined by the Flavor, 
  # but can be specified via block_device for custom sizes.
  block_device {
    uuid                  = "${var.image_UUId}"
    source_type           = "image"
    volume_size           = 40
    destination_type      = "volume"
    delete_on_termination = true
    boot_index            = 0           
  }

}
