

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "auth_url" {
  description = "cloud api url"
  type        = string
  default     = "http://ncs-cloud.lan:5000/v3"
}

variable "region"{
  description = "Region of deployment"
  type        = string
  default     = "RegionOne"
}

variable "key_pair" {
  type = string
}

variable "gitlab_vm_ipv4" {
  type = string
  default = "10.10.20.5"
}

variable "image_UUId" {
  type = string
  default = "e46293b4-bdc6-419c-9150-e7d0edb767e5"
}