variable "auth_url" {
  description = "cloud api url"
  type        = string
}
variable "region" {
  description = "cloud api url"
  type        = string
}
variable "internal_network" {
  description = "Internal network"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet" {
  description = "Pinhole subnet"
  type        = string
  default     = "service_private_net"
}

variable "pinhole_admin_pass" {
    type = string
    sensitive = true
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


variable "key_pair" {
  type = string
  sensitive = true
}