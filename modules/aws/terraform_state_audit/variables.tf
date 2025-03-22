variable "profile" {
  description = "AWS配置文件名称，用于支持子账号"
  type        = string
  default     = "subaccount" # 默认使用subaccount配置文件
}

variable "cloudtrail_name" {
  description = "CloudTrail跟踪的名称"
  type        = string
  default     = "terraform-state-trail"
}

variable "s3_bucket_name" {
  description = "存储CloudTrail日志的S3存储桶名称"
  type        = string
}

variable "is_multi_region" {
  description = "是否为多区域跟踪"
  type        = bool
  default     = true
}

variable "lambda_function_name" {
  description = "Lambda函数的名称"
  type        = string
  default     = "terraform-state-change-processor"
}

variable "audit_table_name" {
  description = "DynamoDB审计表的名称"
  type        = string
  default     = "terraform-state-audit"
}

variable "enable_ttl" {
  description = "是否启用TTL（生存时间）"
  type        = bool
  default     = true
}

variable "tags" {
  description = "要应用到所有资源的标签"
  type        = map(string)
  default     = {}
}