variable "auth_url" {
  description = "cloud api url"
  type        = string
}
variable "region" {
  description = "cloud api url"
  type        = string
}
variable "vm_ipv4" {
  type = string
 
}

variable "image_uuid" {
  type = string
 
}
variable "ssh_key_file" {
  type = string
  sensitive = true
}

variable "mgmt_vault_sg" {
  type = string
}

variable "mgmt_net" {
  type = string
}