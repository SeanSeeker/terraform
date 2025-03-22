# Terraform状态审计模块

这个模块用于为Terraform状态文件创建审计跟踪系统。它使用CloudTrail、Lambda和DynamoDB来跟踪和记录对Terraform状态文件的所有更改，包括谁在什么时间进行了更改。

## 功能

- 创建CloudTrail跟踪以监控S3存储桶活动
- 设置Lambda函数处理S3事件并查询CloudTrail获取用户信息
- 使用DynamoDB表存储审计记录
- 支持TTL自动清理旧记录

## 使用方法

```hcl
module "terraform_state_audit" {
  source = "./modules/aws/terraform_state_audit"

  s3_bucket_name = "your-terraform-state-bucket"
  
  # 可选参数
  cloudtrail_name     = "terraform-state-audit-trail"
  is_multi_region     = false
  lambda_function_name = "terraform-state-change-processor"
  audit_table_name    = "terraform-state-audit"
  enable_ttl          = false
  
  tags = {
    Environment = "Management"
    Purpose     = "Terraform State Audit"
  }
}
```

## 输入变量

| 名称 | 描述 | 类型 | 默认值 | 必填 |
|------|-------------|------|---------|:--------:|
| s3_bucket_name | 存储Terraform状态文件的S3存储桶名称 | `string` | n/a | 是 |
| cloudtrail_name | CloudTrail跟踪的名称 | `string` | `"terraform-state-audit-trail"` | 否 |
| is_multi_region | 是否启用多区域跟踪 | `bool` | `false` | 否 |
| lambda_function_name | 处理S3事件的Lambda函数名称 | `string` | `"terraform-state-change-processor"` | 否 |
| audit_table_name | 存储审计记录的DynamoDB表名称 | `string` | `"terraform-state-audit"` | 否 |
| enable_ttl | 是否启用DynamoDB表的TTL | `bool` | `false` | 否 |
| tags | 要应用于所有资源的标签 | `map(string)` | `{}` | 否 |

## 输出

| 名称 | 描述 |
|------|-------------|
| cloudtrail_arn | 创建的CloudTrail跟踪的ARN |
| lambda_function_arn | 创建的Lambda函数的ARN |
| dynamodb_table_name | 创建的DynamoDB审计表的名称 |
| dynamodb_table_arn | 创建的DynamoDB审计表的ARN |

## 注意事项

- 确保AWS凭证具有创建和管理CloudTrail、Lambda和DynamoDB资源的权限
- 此模块应该与存储Terraform状态的S3存储桶一起使用
- 可以通过DynamoDB表查询审计记录，了解谁在什么时间对Terraform状态进行了更改