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
  sensitive = true
}
variable "image_uuid" {
  type = string
 
}