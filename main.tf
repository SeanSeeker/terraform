# 主配置文件
# Provider配置已移至provider.tf

# 网络模块
module "network" {
  source = "./modules/volcengine/network"

  region                  = var.region
  vpc_base_name           = var.vpc_base_name
  vpc_cidr                = var.vpc_cidr
  zone_subnet_counts_for_region = var.zone_subnet_counts[var.region]
  region_short            = var.region_short_map[var.region]
}

# Cloudflare DNS模块
module "dns" {
  source = "./modules/cloudflare/dns"

  zone_id     = var.cloudflare_zone_id
  domain      = var.domain_name
  dns_records = [
    {
      name  = "www"
      value = module.network.vpc_id # 示例：可以引用其他模块的输出
      type  = "TXT"
    }
  ]
}

# 后续可以添加其他模块，如：
# module "ecs" {
#   source = "./modules/ecs"
#   vpc_id = module.network.vpc_id
#   subnet_ids = module.network.subnet_ids
# }

# module "rds" {
#   source = "./modules/rds"
#   vpc_id = module.network.vpc_id
#   subnet_ids = module.network.subnet_ids
# }

# module "slb" {
#   source = "./modules/slb"
#   vpc_id = module.network.vpc_id
#   subnet_ids = module.network.subnet_ids
# }
