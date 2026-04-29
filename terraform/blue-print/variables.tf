variable "auth_url" {
  description = "cloud api url"
  type        = string
  default     = "http://ncs-cloud.lan:5000/v3"
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

variable "data_net_range" {
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
variable "public_cidr" {
  type        = string
}
variable "physical_router_gateway_ip" {
  type        = string
}
variable "public_allocation_pool_start" {
  type        = string
}
variable "public_allocation_pool_end" {
  type        = string
}
variable "dns_local_ip" {
  type        = string
}
variable "vlan_id" {
  type        = number
  default = 20
}
variable "public_network_type" {
  type        = string
  default = "vlan"
}
variable "public_interface_name" {
  type = string
  default = "physnet1"
}
variable "public_net_name" {
  type = string
  default = "public"
}
variable "public_subnet_name" {
  type = string
  default = "public_subnet"
}

variable "vpc_router_01_name" {
  type        = string
  default = "vpc_router_01"
}

variable "mgmt_subnet_net_name" {
  type = string
  default = "mgmt_subnet"
}

variable "data_subnet_net_name" {
  type = string
  default = "data_subnet"
}
variable "service_subnet_net_name" {
  type = string
  default = "service_subnet"
}
variable "k3s_subnet_net_name" {
  type = string
  default = "k3s_subnet"
}
variable "cluster-auth-key" {
  type = string
  default = "cluster-auth-key"
}