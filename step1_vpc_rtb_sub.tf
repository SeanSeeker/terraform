locals {
  region_short    = lookup(var.region_short_map, var.region, "default")  # 获取地区缩写
  vpc_name        = "${var.vpc_base_name}_${local.region_short}_vpc"      # VPC 名称
  selected_zones  = var.zone_subnet_counts[var.region]  # 选择当前 region 的 zone
  zones           = flatten([for zone, count in local.selected_zones : [for i in range(count) : { zone = zone, index = i }]])
  subnet_cidrs    = [for i in range(length(local.zones)) : cidrsubnet(var.vpc_cidr, 8, i)]
}

resource "volcengine_vpc" "main" {
  vpc_name   = local.vpc_name
  cidr_block = var.vpc_cidr
}
resource "volcengine_route_table" "main" {
  route_table_name   = "${var.vpc_base_name}_${local.region_short}_route_table"  # 自定义路由表名称
  vpc_id = volcengine_vpc.main.id
}
# 创建子网
resource "volcengine_subnet" "subnets" {
  count        = length(local.zones)
  subnet_name  = "${var.vpc_base_name}_${local.region_short}_${local.zones[count.index].zone}_${local.zones[count.index].index + 1}" # 修改的命名格式
  vpc_id       = volcengine_vpc.main.id
  cidr_block   = local.subnet_cidrs[count.index]
  zone_id      = local.zones[count.index].zone
}

output "vpc_name" {
  value = local.vpc_name
}
