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
          - ${file(var.ssh_public_key)}
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
  flavor_name     = "m1.medium"             # Equivalent to your 4-core / 8GB RAM
  key_pair        = "${var.key_pair}"           # Pre-registered OpenStack keypair
  security_groups = ["internal-sg","gitlab-sg"]
  user_data       = local.gitlab_user_data
  config_drive    = true

  network {
    name = "data_private_net"
    fixed_ip_v4 = "${var.gitlab_vm_ipv4}"
  }

  block_device {
    uuid                  = var.image_UUId
    source_type           = "image"
    volume_size           = 40
    destination_type      = "volume"
    volume_type           = "ncs-nvme"
    delete_on_termination = false
    boot_index            = 0           
  }

}
