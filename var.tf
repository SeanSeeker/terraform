variable "region" {
  description = "The region to deploy resources in"
  type        = string
#   default     = "cn-beijing"
  default     = "cn-shanghai"
}

variable "vpc_base_name" {
  description = "Base name of the VPC"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "zone_subnet_counts" {
  description = "Mapping of region to zones and subnet counts"
  type        = map(map(number))
  default = {
    "cn-beijing" = {
      "cn-beijing-a" = 2
      "cn-beijing-b" = 2
    }
    "cn-shanghai" = {
      "cn-shanghai-a" = 2
      "cn-shanghai-b" = 2
    }
  }
}
variable "region_short_map" {
  description = "Mapping from full region name to short name"
  type        = map(string)
  default = {
    "cn-beijing"  = "bj"
    "cn-shanghai" = "sh"
    "cn-guangzhou" = "gz"
    } 
} 