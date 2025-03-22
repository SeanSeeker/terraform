# AWS区域变量
# 指定在哪个AWS区域创建资源
# 选择区域时应考虑：
# 1. 延迟 - 选择离您或团队最近的区域
# 2. 合规 - 某些数据可能需要存储在特定地区
# 3. 成本 - 不同区域的价格可能不同
variable "aws_region" {
  description = "AWS区域，用于创建S3存储桶"
  type        = string
  default     = "us-west-1" # 美国西部加利福尼亚北部区域
}

# AWS配置文件变量
# 使用AWS配置文件支持多账号管理
# 这是AWS CLI的功能，允许在~/.aws/credentials中定义多个配置文件
# 使用子账号而非主账号是AWS安全最佳实践
variable "aws_profile" {
  description = "AWS配置文件名称，用于支持子账号"
  type        = string
  default     = "default" # 默认使用default配置文件
}

# S3存储桶名称变量
# S3存储桶名称在全球范围内必须唯一
# 建议使用组织名称或项目名称作为前缀
# 例如：company-terraform-state或project-terraform-state
variable "bucket_name" {
  description = "存储Terraform状态文件的S3存储桶名称"
  type        = string
  default     = "sean-terraform-state-bucket"
}

# 是否创建DynamoDB表用于状态锁定
# 状态锁定在团队环境中特别重要，可以防止并发操作导致的状态文件冲突
# 对于个人项目，可以设置为false以节省成本
# 对于团队项目，强烈建议设置为true
variable "create_dynamodb_lock_table" {
  description = "是否创建DynamoDB表用于状态锁定"
  type        = bool
  default     = false
}

# DynamoDB表名称变量
# 用于Terraform状态锁定的DynamoDB表名称
# 只有当create_dynamodb_lock_table为true时才会使用
variable "dynamodb_table_name" {
  description = "用于Terraform状态锁定的DynamoDB表名称"
  type        = string
  default     = "terraform-state-lock"
}