

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "auth_url" {
  description = "cloud api url"
  type        = string
  default     = "https://mycloud.lan:5000/v3"
}

variable "region"{
  description = "Region of deployment"
  type        = string
  default     = "RegionOne"
}

variable "key_pair" {
  type = string
  default = "k3s-cluster-key"
}

variable "gitlab_vm_ipv4" {
  type = string
  default = "k3s-cluster-key"
}