variable "region" {
  description = "部署区域"
  type        = string
}

variable "vpc_base_name" {
  description = "VPC基础名称"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC的CIDR块"
  type        = string
}

# 以下变量从根模块传入，不在此处定义
variable "zone_subnet_counts_for_region" {
  description = "当前区域的可用区和子网数量映射"
  type        = map(number)
}

variable "region_short" {
  description = "当前区域的简写"
  type        = string
}