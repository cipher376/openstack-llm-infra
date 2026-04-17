variable "auth_url" {
  description = "cloud api url"
  type        = string
  default     = "http://mycloud.lan:5000/v3"
}

variable "jumpbox_flavour" {
  description = "IPv4 for the Bastion"
  type        = string
  default     = "standard.micro"
}

variable "jumpbox_image" {
  description = "IPv4 for the Bastion"
  type        = string
  default     = "Ubuntu-24.04-Minimal"
}

