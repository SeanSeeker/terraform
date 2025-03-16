variable "region" {
  description = "The region to deploy resources in"
  type        = string
#   default     = "cn-beijing"
  default     = "cn-shanghai"
#   default     = "cn-guangzhou"
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
    "cn-guangzhou" = {
      "cn-guangzhou-a" = 2
      "cn-guangzhou-b" = 2
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

# Cloudflare相关变量
# 这些变量应在terraform.tfvars中设置具体值
variable "cloudflare_zone_id" {
  description = "Cloudflare区域ID，可在Cloudflare控制面板的「概述」页面右下角找到"
  type        = string
  default     = "" # 在terraform.tfvars中设置实际值
}

variable "domain_name" {
  description = "域名，例如example.com"
  type        = string
  default     = "" # 在terraform.tfvars中设置实际值
} 

# 推荐使用环境变量CLOUDFLARE_API_TOKEN设置，而不是在tfvars文件中
variable "cloudflare_api_token" {
  description = "Cloudflare API Token，推荐通过环境变量CLOUDFLARE_API_TOKEN设置"
  type        = string
  sensitive   = true
  default     = "" # 优先使用环境变量CLOUDFLARE_API_TOKEN
} 

# 以下变量已注释，推荐使用环境变量方式提供认证信息
# 可以通过设置环境变量 VOLCENGINE_ACCESS_KEY 和 VOLCENGINE_SECRET_KEY
# 或者取消注释以下代码并在terraform.tfvars中定义变量值

# variable "access_key" {
#   description = "火山引擎访问密钥ID"
#   type        = string
#   sensitive   = true
# }

# variable "secret_key" {
#   description = "火山引擎访问密钥密码"
#   type        = string
#   sensitive   = true
# }