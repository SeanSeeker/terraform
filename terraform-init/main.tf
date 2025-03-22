# S3后端存储桶创建模块
# 这个模块专门用于创建和管理Terraform状态存储的S3存储桶
# 注意：这个模块使用本地状态存储，而不是远程状态存储
# 这解决了"鸡和蛋"的问题：我们需要使用S3作为Terraform的后端存储，但S3存储桶本身也需要被管理

# AWS提供者配置
# region: 指定AWS区域，从变量获取
# profile: 指定AWS配置文件，支持使用子账号而非主账号操作（安全最佳实践）
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# 创建S3存储桶用于存储Terraform状态文件
# 这个存储桶将用作所有Terraform项目的远程状态存储
# 状态文件包含敏感信息，因此需要特别注意安全配置
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name  # 存储桶名称，全局唯一

  # 防止意外删除此存储桶
  # 这是一个重要的安全特性，防止terraform destroy命令删除此存储桶
  # 如果确实需要删除，需要先手动修改此配置或使用AWS控制台
  lifecycle {
    prevent_destroy = true
  }

  # 资源标签，用于分类和管理
  tags = {
    Name        = var.bucket_name
    Environment = "Management"  # 表明这是管理性质的资源
    Purpose     = "Terraform State Storage"
    ManagedBy   = "Terraform"
  }
}

# 启用存储桶版本控制
# 版本控制允许保留状态文件的多个版本，这样可以在意外更改或删除时恢复到之前的状态
# 这是一个重要的安全特性，特别是在团队协作环境中
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id  # 引用上面创建的存储桶
  versioning_configuration {
    status = "Enabled"  # 启用版本控制
  }
}

# 启用存储桶服务器端加密
# 加密确保存储在S3中的状态文件内容被加密，保护敏感信息
# 即使有人获得了对存储桶的访问权限，没有密钥也无法读取内容
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # 使用AES-256加密算法
    }
  }
}

# 阻止公共访问
# 这是S3存储桶的关键安全配置，确保状态文件不会被公开访问
# 所有四个设置都设为true，提供最严格的公共访问保护
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true  # 阻止公共访问控制列表
  block_public_policy     = true  # 阻止公共存储桶策略
  ignore_public_acls      = true  # 忽略公共访问控制列表
  restrict_public_buckets = true  # 限制公共存储桶访问
}

# 可选：创建DynamoDB表用于状态锁定
# 状态锁定是防止并发操作冲突的重要机制
# 当多个用户或自动化流程同时运行Terraform时，锁定确保只有一个操作可以修改状态
# 这防止了状态文件损坏和资源配置冲突
resource "aws_dynamodb_table" "terraform_locks" {
  # 条件创建：只有当变量create_dynamodb_lock_table为true时才创建
  count = var.create_dynamodb_lock_table ? 1 : 0

  name         = var.dynamodb_table_name  # 表名
  billing_mode = "PAY_PER_REQUEST"        # 按请求付费模式，适合低频访问
  hash_key     = "LockID"                 # 主键，Terraform使用这个键来创建和检查锁

  # 定义LockID属性
  attribute {
    name = "LockID"  # 属性名称
    type = "S"       # 字符串类型
  }

  # 资源标签
  tags = {
    Name        = var.dynamodb_table_name
    Environment = "Management"
    Purpose     = "Terraform State Locking"
    ManagedBy   = "Terraform"
  }
}

# 输出值定义
# 这些输出可以被其他模块或脚本引用，例如init_s3_backend.sh脚本
output "bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "S3存储桶名称，用于配置Terraform后端"
}

output "bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "S3存储桶ARN（Amazon资源名称），用于IAM策略或跨账号访问配置"
}

output "dynamodb_table_name" {
  value       = var.create_dynamodb_lock_table ? aws_dynamodb_table.terraform_locks[0].name : null
  description = "DynamoDB表名称（如果创建），用于配置Terraform状态锁定"
  # 条件输出：只有当创建了DynamoDB表时才输出表名，否则为null
}