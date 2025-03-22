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
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3远程状态存储配置
  # 使用AWS S3作为Terraform状态文件的远程存储
  # 这样可以实现团队协作、版本控制和状态备份
  backend "s3" {
    bucket  = "sean-terraform-state-bucket"  # S3存储桶名称，必须已存在
    key     = "terraform.tfstate"           # 状态文件在存储桶中的路径
    region  = "us-west-1"                   # AWS区域（美西-加州-北部）
    encrypt = true                          # 启用服务器端加密，保护状态文件内容
    # 如果使用DynamoDB进行状态锁定，取消下面一行的注释
    # dynamodb_table = "terraform-state-lock" # DynamoDB表名，用于状态锁定
  }
}

# 火山引擎Provider配置
# 火山引擎是字节跳动旗下的云服务平台，提供计算、存储、网络等基础设施服务
# 认证方式：
# 1. 推荐使用环境变量方式提供认证信息（安全最佳实践）
#    设置环境变量 VOLCENGINE_ACCESS_KEY 和 VOLCENGINE_SECRET_KEY
# 2. 也可以在terraform.tfvars中设置access_key和secret_key变量（不推荐）
provider "volcengine" {
  region = var.region  # 使用变量定义的区域，如cn-beijing、cn-shanghai等
}

# Cloudflare Provider配置
# Cloudflare提供CDN、DNS、DDoS防护等服务
# 认证方式：
# 1. 强烈推荐使用环境变量方式提供认证信息（安全最佳实践）
#    - 使用API令牌（推荐）：export CLOUDFLARE_API_TOKEN="您的API令牌"
#    - 或使用API密钥：同时设置CLOUDFLARE_EMAIL和CLOUDFLARE_API_KEY
# 2. 也可以在代码中使用变量（不推荐，存在泄露风险）
provider "cloudflare" {
  # 如果环境变量未设置，则尝试使用变量中的API Token
  # 但出于安全考虑，强烈建议使用环境变量
  api_token = var.cloudflare_api_token == "" ? null : var.cloudflare_api_token
}

# AWS Provider配置
# AWS是亚马逊的云服务平台，提供全球范围的云计算服务
# 认证方式：
# 1. 强烈推荐使用环境变量方式提供认证信息（安全最佳实践）
#    export AWS_ACCESS_KEY_ID="您的AWS访问密钥ID"
#    export AWS_SECRET_ACCESS_KEY="您的AWS访问密钥密码"
# 2. 使用配置文件方式（~/.aws/credentials）
#    export AWS_PROFILE="subaccount"
# 3. 在EC2实例上使用IAM角色（生产环境推荐）
provider "aws" {
  region  = var.aws_region  # AWS区域，如us-west-1
  profile = var.aws_profile # AWS配置文件，支持使用子账号
}