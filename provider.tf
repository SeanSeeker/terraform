terraform {
  required_providers {
    volcengine = {
      source  = "volcengine/volcengine"
      version = "0.0.161"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# 火山引擎Provider配置
# 推荐使用环境变量方式提供认证信息
# 可以通过设置环境变量 VOLCENGINE_ACCESS_KEY 和 VOLCENGINE_SECRET_KEY
provider "volcengine" {
  region = var.region
}

# Cloudflare Provider配置
# 强烈推荐使用环境变量方式提供认证信息
# 设置方法：
# export CLOUDFLARE_API_TOKEN="您的API令牌"
# 或者同时设置：
# export CLOUDFLARE_EMAIL="您的邮箱"
# export CLOUDFLARE_API_KEY="您的API密钥"
provider "cloudflare" {
  # 如果环境变量未设置，则尝试使用变量中的API Token
  # 但出于安全考虑，强烈建议使用环境变量
  api_token = var.cloudflare_api_token == "" ? null : var.cloudflare_api_token
}