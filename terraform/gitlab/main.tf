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
      - fallocate -l 4G /swapfile
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
  image_name      = "Ubuntu-24.04-Minimal" # The name of your image in Glance
  flavor_name     = "standard.large"             # Equivalent to your 4-core / 8GB RAM
  key_pair        = "${var.key_pair}"           # Pre-registered OpenStack keypair
  security_groups = ["sg-k3s-internal", "sg-management"]
  user_data       = local.gitlab_user_data

  network {
    name = "k3-private-net"
    fixed_ip_v4 = "${var.gitlab_vm_ipv4}"
  }

  # Primary Disk (OS) - Often defined by the Flavor, 
  # but can be specified via block_device for custom sizes.
  block_device {
    uuid                  = "uuid-of-ubuntu-image"
    source_type           = "image"
    volume_size           = 40
    destination_type      = "volume"
    delete_on_termination = true
  }

  # Secondary Disk (1TB for Models)
  block_device {
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = 1000
    delete_on_termination = false # Keep data if VM is deleted
  }
}

resource "openstack_networking_floatingip_v2" "gitlab_fip" {
  pool = "public" # This is the name of your external/public network pool
}
resource "openstack_compute_floatingip_associate_v2" "gitlab_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.gitlab_fip.address
  instance_id = openstack_compute_instance_v2.gitlab_server.id
}