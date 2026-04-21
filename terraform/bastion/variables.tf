variable "auth_url" {
  description = "cloud api url"
  type        = string
}
variable "region" {
  description = "cloud api url"
  type        = string
}

variable "ssh_key_file" {
  type = string
}
variable "key_pair" {
  type = string
}

variable "image_uuid" {
  type = string
 
}

variable "ssh_private_key_file" {
  type = string
}
variable "cloud_service_vm_IPv4" {
  type = string
}
variable "bastion_ipv4" {
  type = string
}