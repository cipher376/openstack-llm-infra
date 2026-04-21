
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


# 1. Define the Cluster Template for K3s on Ubuntu
resource "openstack_containerinfra_clustertemplate_v1" "k3s_template" {
  name                  = "k3s-ml-cluster"
  image                 = var.image # Must have magnum-agent
  coe                   = "kubernetes"
  flavor                = "m1.medium"
  master_flavor         = "m1.medium"
  
        # Size in GB for the boot volume
  volume_driver         = "cinder"


  # Tell Magnum NOT to install a default CNI
  network_driver        = "none" 
  floating_ip_enabled   = false
  master_lb_enabled     = false

  labels = {
    "container_runtime" = "containerd"
    "os"                = "ubuntu"
    # Custom K3s arguments to disable Flannel and NetworkPolicy
    "k3s_args"          = "--flannel-backend=none --disable-network-policy"
    # Optional: If you want Cilium to replace kube-proxy entirely
    "kube_proxy_replacement" = "strict" 
    "boot_volume_size"      = var.boot_volume_size
    "boot_volume_type" = "ssd"
  }
}

# 2. Deploy the Base Cluster (1 Master + 2 Standard Workers)
resource "openstack_containerinfra_cluster_v1" "k3s_cluster" {
  name                = "k3s-cluster"
  cluster_template_id = openstack_containerinfra_clustertemplate_v1.k3s_template.id
  master_count        = 1
  node_count          = 2 
  keypair             = "ssh_key_pair"
}

# 3. Add the 4th VM as a GPU Nodegroup (No Floating IP inherited)
resource "openstack_containerinfra_nodegroup_v1" "gpu_worker" {
  name       = "gpu-worker-pool"
  cluster_id = openstack_containerinfra_cluster_v1.k3s_cluster.id
  node_count = 1
  flavor_id     = var.gpu_flavor # Your GPU-enabled flavor
  role       = "worker"

  labels = {
    "gpu" = "true"
  }
}