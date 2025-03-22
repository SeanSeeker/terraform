# 声明所需的提供商
# 指定火山引擎提供商的源和版本
# 确保使用兼容的提供商版本，避免因版本不兼容导致的问题
terraform {
  required_providers {
    volcengine = {
      source  = "volcengine/volcengine" # 提供商源，格式为 "命名空间/提供商名称"
      version = "0.0.161"              # 提供商版本，使用特定版本以确保稳定性
    }
  }
}

# 定义本地变量
# 本地变量用于简化配置和提高代码可读性
# 这些变量只在模块内部可见，不会暴露给外部
locals {
  region_short = var.region_short # 直接使用传入的区域简称，如bj、sh等

  # 处理可用区和子网信息
  # 使用flatten函数将嵌套列表转换为扁平列表
  # 这里根据每个可用区需要创建的子网数量生成子网配置
  zones_raw = flatten([
    for zone, count in var.zone_subnet_counts_for_region : [
      for i in range(count) : {
        zone  = zone   # 可用区ID，如cn-beijing-a
        index = i      # 子网索引，从0开始
      }
    ]
  ])

  # 使用原始的zones_raw，不进行排序
  # 保持可用区和子网的原始顺序
  zones = local.zones_raw

  # 生成子网CIDR
  # 使用cidrsubnet函数从VPC CIDR块中划分子网
  # 每个子网的CIDR块大小为VPC CIDR块的1/256（newbits=8）
  subnet_cidrs = [
    for i, zone in local.zones : cidrsubnet(var.vpc_cidr, 8, i) # 第i个子网的CIDR块
  ]
}

# 创建VPC（虚拟私有云）
# VPC是一个逻辑隔离的网络环境，用于部署云资源
# 它提供了网络隔离、安全控制和自定义网络配置的能力
resource "volcengine_vpc" "main" {
  vpc_name   = "${var.vpc_base_name}_${local.region_short}_vpc" # VPC名称，采用统一命名规范，如prod_sh_vpc
  cidr_block = var.vpc_cidr                                    # VPC的IP地址范围，如10.0.0.0/16
}

# 创建子网
# 子网是VPC内的IP地址段，用于进一步划分网络
# 子网与可用区关联，实现跨可用区的高可用架构
resource "volcengine_subnet" "subnets" {
  count       = length(local.zones)                                                                                           # 创建的子网数量
  subnet_name = "${var.vpc_base_name}_${local.region_short}_${local.zones[count.index].zone}_${local.zones[count.index].index + 1}" # 子网名称，如prod_sh_cn-shanghai-a_1
  vpc_id      = volcengine_vpc.main.id                                                                                      # 关联的VPC ID
  cidr_block  = local.subnet_cidrs[count.index]                                                                             # 子网CIDR块，如10.0.0.0/24
  zone_id     = local.zones[count.index].zone                                                                               # 可用区ID，如cn-shanghai-a
}

# 创建路由表
# 路由表包含一组路由规则，用于控制VPC内的网络流量
# 每个子网都关联一个路由表，决定了子网内流量的转发方式
resource "volcengine_route_table" "main" {
  route_table_name = "${var.vpc_base_name}_${local.region_short}_route_table" # 路由表名称，如prod_sh_route_table
  vpc_id           = volcengine_vpc.main.id                                # 关联的VPC ID
}