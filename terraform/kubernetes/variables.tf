variable "auth_url" {
  description = "cloud api url"
  type        = string
}
variable "region" {
  description = "cloud api url"
  type        = string
}


variable "image_uuid" {
  type = string
}

variable "ssh_key_file" {
  type = string
  sensitive = true
}

variable "gpu_worker_01_vm_ipv4" {
  type = string
  description = "Static ipv4 for GPU worker 01"
}

variable "inference_worker_01_vm_ipv4" {
  type = string
  description = "Static ipv4 for cpu inference worker 01"
}
variable "k3s_master_01_vm_ipv4" {
  type = string
}
variable "k3s_worker_01_vm_ipv4" {
  type = string
}
variable "k3s_worker_02_vm_ipv4" {
  type = string
}

variable "k3s_subnet" {
  type = string
  default = "k3s_private_net"
}