# 主配置文件
# 本文件定义了各个模块的调用和配置
# Provider配置已移至provider.tf文件，便于管理

# 火山引擎网络模块
# 用于创建VPC、子网和路由表等网络资源
# 网络是所有云服务的基础，需要先创建好网络资源，才能部署其他服务
module "network" {
  source = "./modules/volcengine/network"  # 模块源路径

  # 传递参数到模块
  region                        = var.region                         # 部署区域，如cn-beijing
  vpc_base_name                 = var.vpc_base_name                  # VPC基础名称，用于生成资源名称
  vpc_cidr                      = var.vpc_cidr                       # VPC的CIDR块，如10.0.0.0/16
  zone_subnet_counts_for_region = var.zone_subnet_counts[var.region] # 当前区域的可用区和子网数量映射
  region_short                  = var.region_short_map[var.region]   # 区域简写，用于资源命名
}

# Cloudflare DNS模块
# 用于管理Cloudflare上的DNS记录
# DNS记录用于将域名解析到IP地址或其他资源
# Cloudflare提供了额外的安全功能，如DDoS防护和CDN加速
module "dns" {
  source = "./modules/cloudflare/dns"  # 模块源路径

  # 传递参数到模块
  zone_id = var.cloudflare_zone_id  # Cloudflare区域ID，可在Cloudflare控制面板找到
  domain  = var.domain_name        # 域名，如example.com
  
  # DNS记录列表，每个记录包含名称、值、类型等属性
  dns_records = [
    {
      name  = "www"              # 子域名，完整域名为www.example.com
      value = "123.123.123.123" # IP地址或目标值
      type  = "A"               # 记录类型：A记录将域名指向IPv4地址
    },
    {
      name  = "test1"              # 子域名，完整域名为test.example.com
      value = "124.124.124.122"   # IP地址
      type  = "A"                 # A记录
      # ttl   = 1                  # 生存时间，启用代理时必须设为1（自动TTL）
      # proxied = true             # 是否启用Cloudflare代理（CDN、安全防护）
    }
  ]
}

# AWS S3存储桶模块
# module "s3_bucket" {
#   source = "./modules/aws/s3"
#   
#   bucket_name       = "my-example-bucket"
#   enable_versioning = true
#   block_public_access = true
#   tags = {
#     Environment = "Production"
#     Project     = "MyProject"
#   }
#   lifecycle_rules = [
#     {
#       id      = "archive"
#       enabled = true
#       transitions = [
#         {
#           days          = 30
#           storage_class = "STANDARD_IA"
#         },
#         {
#           days          = 90
#           storage_class = "GLACIER"
#         }
#       ]
#       expiration = {
#         days = 365
#       }
#     }
#   ]
# }

# Terraform状态审计模块
# 用于监控和记录Terraform状态文件的变更
# 这对于安全审计、合规性和问题排查非常重要
# 该模块使用AWS CloudTrail、Lambda和DynamoDB实现审计功能
module "terraform_state_audit" {
  source = "./modules/aws/terraform_state_audit"  # 模块源路径

  # 必需参数
  s3_bucket_name = var.terraform_state_bucket  # 存储Terraform状态文件的S3存储桶名称

  # 可选参数（使用默认值或自定义）
  cloudtrail_name      = "terraform-state-audit-trail"      # CloudTrail跟踪的名称
  is_multi_region      = false                             # 是否为多区域跟踪
  lambda_function_name = "terraform-state-change-processor" # Lambda函数名称，用于处理状态变更事件
  audit_table_name     = "terraform-state-audit"           # DynamoDB审计表名称，用于存储审计记录
  enable_ttl           = true                              # 是否启用TTL（生存时间），用于自动删除旧记录

  # 资源标签
  tags = {
    Environment = "Management"          # 环境标签
    Purpose     = "Terraform State Audit" # 用途标签
  }
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
