# Cloudflare配置
# 已替换为实际值
cloudflare_zone_id = "302b37d92355af29b32b2dae4e3d6aba" # 在Cloudflare控制面板的「概述」页面右下角找到
domain_name        = "seanseeker.com"

# 不推荐在此设置API Token，请使用环境变量CLOUDFLARE_API_TOKEN
# export CLOUDFLARE_API_TOKEN="您的API令牌"

# 火山引擎区域配置
region = "cn-shanghai"

# AWS S3后端存储配置
# aws_region = "ap-northeast-1" # 默认为ap-northeast-1
# terraform_state_bucket = "terraform-state-storage-bucket" # 默认为terraform-state-storage-bucket
# terraform_state_key = "terraform.tfstate" # 默认为terraform.tfstate
# terraform_state_dynamodb_table = "terraform-state-lock" # 默认为terraform-state-lock

# 其他配置
# vpc_base_name = "prod" # 默认为prod
# vpc_cidr = "10.0.0.0/16" # 默认为10.0.0.0/16

# AWS配置文件
aws_profile = "subaccount" # 使用子账号配置文件