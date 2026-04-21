variable "auth_url" {
  description = "cloud api url"
  type        = string
}
variable "region" {
  description = "cloud api url"
  type        = string
}

variable "image"{
    type = string
}

variable "boot_volume_size"{
    type = number
    default = 40
}
variable "gpu_flavor"{
    type = string
    default = "ai.gpu6gb_01.boot"
}
variable "ssh_key_pair"{
    type = string
}

