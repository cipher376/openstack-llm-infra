variable "auth_url" {
  description = "cloud api url"
  type        = string
  default     = "http://ncs-cloud.lan:5000/v3"
}

variable "bastion_flavour" {
  description = "IPv4 for the Bastion"
  type        = string
  default     = "standard.micro"
}

variable "bastion_image" {
  description = "IPv4 for the Bastion"
  type        = string
  default     = "Ubuntu-24.04-Minimal"
}

variable "key_pair_file" {
  type        = string
}

variable "mgmt_net_range" {
  type        = string
}

variable "mgmt_net" {
  type        = string
}

variable "date_net_range" {
  type        = string
}

variable "data_net" {
  type        = string
}

variable "service_net_range" {
  type        = string
}
variable "service_net" {
  type        = string
}
variable "k3s_net_range" {
  type        = string
}
variable "k3s_net" {
  type        = string
}

