# main.tf - OpenStack Flavor Definitions for AI Cluster

terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53"
    }
  }
}

# Configure the OpenStack provider
# Ensure environment variables are set (OS_AUTH_URL, OS_USERNAME, etc.)
provider "openstack" {
  # Configuration can also be done via environment variables
}

# Micro Flavor (Low-resource utilities)
resource "openstack_compute_flavor_v2" "m1_micro_boot" {
  name      = "m1.micro.boot"
  ram       = 512
  vcpus     = 1
  disk      = 8
  is_public = true
}
resource "openstack_compute_flavor_v2" "m1_micro" {
  name      = "m1.micro"
  ram       = 512
  vcpus     = 1
  disk      = 0
  is_public = true
}
# Small Flavor (Standard API services)
resource "openstack_compute_flavor_v2" "m1_mini_boot" {
  name      = "m1.mini.boot"
  ram       = 1024
  vcpus     = 1
  disk      = 10
  is_public = true
}

# Small Flavor (Standard API services)
resource "openstack_compute_flavor_v2" "m1_mini" {
  name      = "m1.mini"
  ram       = 1024
  vcpus     = 1
  disk      = 0
  is_public = true
}

# Small Flavor (Standard API services)
resource "openstack_compute_flavor_v2" "m1_small_boot" {
  name      = "m1.small.boot"
  ram       = 2048
  vcpus     = 1
  disk      = 20
  is_public = true
}

# Small Flavor (Standard API services)
resource "openstack_compute_flavor_v2" "m1_small" {
  name      = "m1.small"
  ram       = 2048
  vcpus     = 1
  disk      = 0
  is_public = true
}

# Medium Flavor (Docker/K8s Workers)
resource "openstack_compute_flavor_v2" "m1_medium_boot" {
  name      = "m1.medium.boot"
  ram       = 4096
  vcpus     = 2
  disk      = 20
  is_public = true
}

# Standard Master Flavor for K3s
resource "openstack_compute_flavor_v2" "m1_medium" {
  name      = "m1.medium"
  ram       = 4096
  vcpus     = 2
  disk      = 0
  is_public = true
}


# Medium Flavor (Docker/K8s Workers)
resource "openstack_compute_flavor_v2" "m1_large_boot" {
  name      = "m1.large.boot"
  ram       = 8192
  vcpus     = 3
  disk      = 40
  is_public = true
}

# Standard Master Flavor for K3s
resource "openstack_compute_flavor_v2" "m1_large" {
  name      = "m1.large"
  ram       = 8192
  vcpus     = 3
  disk      = 0
  is_public = true
}


# Medium Flavor (Docker/K8s Workers)
resource "openstack_compute_flavor_v2" "m1_heavy_boot" {
  name      = "m1.heavy.boot"
  ram       = 16384 
  vcpus     = 8
  disk      = 60
  is_public = true
}

# Standard Master Flavor for K3s
resource "openstack_compute_flavor_v2" "m1_heavy" {
  name      = "m1.heavy"
  ram       = 16384
  vcpus     = 8
  disk      = 0
  is_public = true
}


# AI/GPU Flavor (Legion optimized)
resource "openstack_compute_flavor_v2" "ai_gpu6gb_01_boot" {
  name      = "ai.gpu6gb_01.boot"
  ram       = 16384
  vcpus     = 8
  disk      = 60
  is_public = true
  extra_specs = {
    "pci_passthrough:alias"                 = "nvidia_gpu6gb:1"
    "aggregate_instance_extra_specs:gpu"    = "true"
  }
}

# Super Heavy Inference Flavor
resource "openstack_compute_flavor_v2" "ai_inference_boot" {
  name      = "ai.inference.boot"
  ram       = 32768
  vcpus     = 12
  disk      = 60
  is_public = true
}