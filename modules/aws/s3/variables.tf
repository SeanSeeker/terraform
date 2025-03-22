variable "bucket_name" {
  description = "S3存储桶名称"
  type        = string
}

variable "enable_versioning" {
  description = "是否启用S3存储桶版本控制"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "是否阻止公共访问S3存储桶"
  type        = bool
  default     = true
}

variable "tags" {
  description = "要应用于S3存储桶的标签"
  type        = map(string)
  default     = {}
}

variable "lifecycle_rules" {
  description = "S3存储桶生命周期规则列表"
  type = list(object({
    id      = string
    enabled = bool
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })))
    expiration = optional(object({
      days = number
    }))
  }))
  default = []
}