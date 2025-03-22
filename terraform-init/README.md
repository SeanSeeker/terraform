# Terraform S3后端初始化

这个目录包含用于创建和管理Terraform状态存储的S3存储桶的配置。

## 为什么需要单独的目录？

这解决了"鸡和蛋"的问题：我们需要使用S3作为Terraform的后端存储，但S3存储桶本身也需要被管理。
通过将S3存储桶的创建与主项目分离，我们可以：

1. 使用本地状态存储来管理S3存储桶
2. 在主项目中使用这个已创建的S3存储桶作为远程后端

## 使用方法

### 1. 初始化并创建S3存储桶

```bash
# 确保设置了AWS凭证
export AWS_ACCESS_KEY_ID="您的AWS访问密钥ID"
export AWS_SECRET_ACCESS_KEY="您的AWS访问密钥密码"
# 或者使用配置文件（推荐）
export AWS_PROFILE="subaccount"

# 进入此目录
cd terraform-init

# 初始化Terraform（使用本地状态）
terraform init

# 创建S3存储桶和DynamoDB表（如果启用）
terraform apply
```

### 2. 在主项目中使用S3后端

创建S3存储桶后，返回主项目目录并运行初始化脚本：

```bash
cd ..
./init_s3_backend.sh

# 或指定参数
./init_s3_backend.sh my-terraform-state us-west-1 terraform-state-lock subaccount
```

## 配置选项

可以通过创建`terraform.tfvars`文件或在命令行中传递变量来自定义配置：

```
aws_region = "us-west-1"
bucket_name = "my-terraform-state-bucket"
create_dynamodb_lock_table = true
dynamodb_table_name = "my-terraform-lock-table"
```

## 安全特性

此配置包含以下安全特性：

- S3存储桶配置了`prevent_destroy = true`，以防止意外删除
- 存储桶启用了版本控制，可以恢复之前的状态文件版本
- 启用了服务器端加密，保护状态文件内容
- 阻止了所有公共访问，确保只有授权用户可以访问
- 可选的DynamoDB表用于状态锁定，防止并发操作冲突

## 注意事项

- 确保AWS凭证具有创建S3存储桶和DynamoDB表的权限
- 建议使用子账号而不是主账号来管理Terraform状态
- 定期备份状态文件，以防意外删除或损坏
- 使用DynamoDB表进行状态锁定可以防止团队成员同时修改基础设施