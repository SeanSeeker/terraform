terraform {
  required_providers {
    volcengine = {
      source = "volcengine/volcengine"
      version = "0.0.161"
    }
  }
}

# 定义本地变量
locals {
  region_short = var.region_short  # 直接使用传入的区域简称
  
  # 处理可用区和子网信息
  zones_raw = flatten([
    for zone, count in var.zone_subnet_counts_for_region : [
      for i in range(count) : {
        zone = zone
        index = i
      }
    ]
  ])
  
  # 使用原始的zones_raw，不进行排序
  zones = local.zones_raw
  
  # 生成子网CIDR
  subnet_cidrs = [
    for i, zone in local.zones : cidrsubnet(var.vpc_cidr, 8, i)
  ]
}

# 创建VPC
resource "volcengine_vpc" "main" {
  vpc_name   = "${var.vpc_base_name}_${local.region_short}_vpc"  # VPC 名称，比如prod_sh_vpc
  cidr_block = var.vpc_cidr
}

# 创建子网
resource "volcengine_subnet" "subnets" {
  count        = length(local.zones)
  subnet_name  = "${var.vpc_base_name}_${local.region_short}_${local.zones[count.index].zone}_${local.zones[count.index].index + 1}" # 按照命名规范
  vpc_id       = volcengine_vpc.main.id
  cidr_block   = local.subnet_cidrs[count.index]
  zone_id      = local.zones[count.index].zone
}

# 创建路由表
resource "volcengine_route_table" "main" {
  route_table_name = "${var.vpc_base_name}_${local.region_short}_route_table"
  vpc_id           = volcengine_vpc.main.id
}