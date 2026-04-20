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


# Kubernetes INSTANCE
#=========================================================================
# K3S MASTER
#==========================================================================
resource "openstack_blockstorage_volume_v3" "k3s_master_01_boot_vol" {
  name        = "k3s-master-01-boot-disk"
  size        = 40
  image_id    = var.image_uuid
  description = "Persistent boot disk for cluster Vault"
  volume_type = "ncs-nvme"
}

resource "openstack_compute_instance_v2" "k3s_master_01" {
  name            = "k3s-master-01"
  flavor_name     = "m1.medium"
  security_groups = ["internal-sg", "k3s-internal-sg"]
  config_drive    = true

  # Attach the volume we created above as the boot device
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.k3s_master_01_boot_vol.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false 
  }

  network {
    name        =  var.k3s_subnet
    fixed_ip_v4 = var.k3s_master_01_vm_ipv4
  }

  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    runcmd:
      - apt-get update
      - apt-get install -y ubuntu-drivers-common
      - ubuntu-drivers autoinstall
    EOF
}


#=========================================================================
# GPU WORKER 
#==========================================================================

# 1. Create the NVMe Data Volume
resource "openstack_blockstorage_volume_v3" "gpu_worker_storage" {
  name        = "gpu-worker-local-storage"
  description = "Local storage for AI GPU worker"
  size        = 100
  volume_type = "ncs-nvme"
}

# 2. Create the GPU Worker Instance
resource "openstack_compute_instance_v2" "gpu_worker" {
  name            = "gpu-worker-01"
  image_id        = var.image_uuid
  flavor_name     = "ai.gpu6gb_01.boot"
  security_groups = ["internal-sg", "k3s-internal-sg"]
  config_drive    = true

  network {
    name        = var.k3s_subnet
    fixed_ip_v4 = var.gpu_worker_01_vm_ipv4
  }

  # Cloud-Init for Driver Installation
  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    runcmd:
      - apt-get update
      - apt-get install -y ubuntu-drivers-common
      - ubuntu-drivers autoinstall
  EOF
}

resource "openstack_compute_volume_attach_v2" "va_1" {
  instance_id = openstack_compute_instance_v2.gpu_worker.id
  volume_id   = openstack_blockstorage_volume_v3.gpu_worker_storage.id
}

#==========================================================================
# Inference WORKER 
#==========================================================================

resource "openstack_compute_instance_v2" "inference_worker" {
  name            = "inference-worker-01"
  image_id        = var.image_uuid
  flavor_name     = "ai.inference.boot"
  security_groups = ["internal-sg", "k3s-internal-sg"]
  config_drive    = true

  network {
    name        = var.k3s_subnet
    fixed_ip_v4 = var.inference_worker_01_vm_ipv4
  }

  # Cloud-Init for Driver Installation
  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    runcmd:
      - apt-get update
      - apt-get install -y ubuntu-drivers-common
      - ubuntu-drivers autoinstall
  EOF
}

#==========================================================================
# REGULAR WORKERS 
#==========================================================================


resource "openstack_compute_instance_v2" "k3s_worker_01" {
  name            = "k3s-worker-01"
  flavor_name     = "m1.large"
  security_groups = ["internal-sg","k3s-internal-sg"]
  config_drive    = true


  network {
    name        = var.k3s_subnet
    fixed_ip_v4 = var.k3s_worker_01_vm_ipv4

  }
  
  block_device {
    uuid        = var.image_uuid
    source_type           = "image"
    volume_size           = 40
    destination_type      = "volume"
    volume_type           = "ncs-nvme"
    delete_on_termination = true
    boot_index            = 0           
  }
  # Cloud-Init for Driver Installation
  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    runcmd:
      - apt-get update
      - apt-get install -y ubuntu-drivers-common
      - ubuntu-drivers autoinstall
  EOF

}

resource "openstack_compute_instance_v2" "k3s_worker_02" {
  name            = "k3s-worker-02"
  flavor_name     = "m1.large"
  security_groups = ["internal-sg","k3s-internal-sg"]
  config_drive    = true


  network {
    name        = var.k3s_subnet
    fixed_ip_v4 = var.k3s_worker_02_vm_ipv4

  }
  
  block_device {
    uuid        = var.image_uuid
    source_type           = "image"
    volume_size           = 40
    destination_type      = "volume"
    volume_type           = "ncs-nvme"
    delete_on_termination = true
    boot_index            = 0           
  }
  # Cloud-Init for Driver Installation
  user_data = <<-EOF
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${file(var.ssh_key_file)}
    runcmd:
      - apt-get update
      - apt-get install -y ubuntu-drivers-common
      - ubuntu-drivers autoinstall
  EOF

}

