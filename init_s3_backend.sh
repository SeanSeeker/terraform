#!/bin/bash

# 初始化S3后端存储并迁移现有状态文件
# 此脚本用于配置Terraform使用AWS S3作为远程后端存储
# 它会检查S3存储桶是否存在，迁移本地状态文件（如果有），并配置provider.tf文件
# 
# 使用方法: ./init_s3_backend.sh [bucket_name] [region] [dynamodb_table] [profile]
# 参数说明:
#   bucket_name    - S3存储桶名称，必须已存在
#   region         - AWS区域，例如us-west-1
#   dynamodb_table - 可选，用于状态锁定的DynamoDB表名称
#   profile        - AWS配置文件名称，用于支持子账号

set -e

# 设置变量默认值
# 如果命令行参数未提供，则使用这些默认值
# 建议在实际使用时通过命令行参数指定具体值
BUCKET_NAME=${1:-"terraform-state-storage-bucket"}  # S3存储桶名称
REGION=${2:-"us-west-1"}                          # AWS区域
DYNAMODB_TABLE=${3:-""}                          # DynamoDB表名称，默认为空
PROFILE=${4:-"subaccount"}                       # AWS配置文件，默认使用subaccount

echo "=== 初始化S3后端存储 ==="
echo "存储桶名称: $BUCKET_NAME"
echo "区域: $REGION"
echo "配置文件: $PROFILE"
if [ -n "$DYNAMODB_TABLE" ]; then
    echo "DynamoDB表名称: $DYNAMODB_TABLE"
fi

# 检查AWS CLI是否已安装
# AWS CLI是与AWS服务交互的命令行工具，此脚本需要它来检查S3存储桶
if ! command -v aws &> /dev/null; then
    echo "错误: 未找到AWS CLI，请先安装AWS CLI"
    echo "安装指南: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# 检查AWS凭证是否已配置
# 脚本需要AWS凭证来访问S3存储桶和DynamoDB表
# 可以通过环境变量或AWS配置文件提供凭证
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "警告: 未设置AWS凭证环境变量"
    echo "请设置以下环境变量:"
    echo "export AWS_ACCESS_KEY_ID=您的访问密钥ID"
    echo "export AWS_SECRET_ACCESS_KEY=您的访问密钥密码"
    echo "继续执行可能会失败..."
    # 如果未设置环境变量，脚本会尝试使用AWS配置文件中的凭证
    # 询问用户是否继续执行
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查S3存储桶是否存在
# 使用AWS CLI的head-bucket命令检查存储桶是否存在且可访问
# 如果存储桶不存在或无法访问，脚本会提供创建存储桶的指导
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" --profile "$PROFILE" 2>/dev/null; then
    echo "错误: 存储桶 '$BUCKET_NAME' 不存在或无法访问"
    echo "请先使用terraform-init目录创建S3存储桶:"
    echo "cd terraform-init"
    echo "terraform init"
    echo "terraform apply -var=\"bucket_name=$BUCKET_NAME\" -var=\"aws_region=$REGION\""
    exit 1
fi

# 检查是否有本地状态文件需要迁移
# 如果存在本地状态文件，脚本会询问是否将其迁移到S3
# 迁移前会创建本地备份，确保数据安全
if [ -f "terraform.tfstate" ]; then
    echo "发现本地状态文件，准备迁移到S3..."
    read -p "是否将本地状态文件迁移到S3? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 备份本地状态文件，使用时间戳确保备份文件名唯一
        cp terraform.tfstate terraform.tfstate.backup.$(date +%s)
        echo "已创建本地状态文件备份"
        
        # 上传状态文件到S3存储桶
        # 使用AWS CLI的cp命令将本地文件上传到S3
        aws s3 cp terraform.tfstate s3://$BUCKET_NAME/terraform.tfstate --region $REGION --profile $PROFILE
        echo "状态文件已上传到S3"
    fi
fi

# 构建Terraform初始化命令
# 使用-reconfigure选项强制重新配置后端，忽略任何现有配置
# 使用-backend-config选项提供S3后端的配置参数
INIT_CMD="terraform init -reconfigure \
    -backend-config=\"bucket=$BUCKET_NAME\" \
    -backend-config=\"key=terraform.tfstate\" \
    -backend-config=\"region=$REGION\" \
    -backend-config=\"profile=$PROFILE\" \
    -backend-config=\"encrypt=true\""

# 如果提供了DynamoDB表名，添加到初始化命令中
# DynamoDB表用于Terraform状态锁定，防止并发操作冲突
if [ -n "$DYNAMODB_TABLE" ]; then
    INIT_CMD="$INIT_CMD \
    -backend-config=\"dynamodb_table=$DYNAMODB_TABLE\""
fi

# 执行Terraform初始化命令
# 这将配置Terraform使用S3作为远程后端存储
echo "初始化Terraform..."
eval $INIT_CMD

# 更新provider.tf文件中的后端配置
# 这一步会修改provider.tf文件，更新S3后端配置
# 包括更新区域、存储桶名称和DynamoDB表名（如果提供）
echo "更新provider.tf文件中的后端配置..."
if [ -f "provider.tf" ]; then
    # 备份原始文件，使用时间戳确保备份文件名唯一
    # 这是一个安全措施，确保在出现问题时可以恢复原始配置
    cp provider.tf provider.tf.backup.$(date +%s)
    
    # 使用sed命令更新区域配置
    # 正则表达式匹配region参数并替换为新值
    sed -i '' "s|region *= *\"[^\"]*\"|region = \"$REGION\"|g" provider.tf
    
    # 使用sed命令更新存储桶名称配置
    # 正则表达式匹配bucket参数并替换为新值
    sed -i '' "s|bucket *= *\"[^\"]*\"|bucket = \"$BUCKET_NAME\"|g" provider.tf
    
    # 如果提供了DynamoDB表名，取消注释并更新配置
    # 这会启用Terraform状态锁定功能
    if [ -n "$DYNAMODB_TABLE" ]; then
        sed -i '' "s|# dynamodb_table = \"[^\"]*\"|dynamodb_table = \"$DYNAMODB_TABLE\"|g" provider.tf
    fi
    
    echo "provider.tf文件已更新"
fi

# 完成初始化并显示成功消息
# 此时，Terraform已配置为使用S3作为远程后端存储
# 所有后续的Terraform操作将使用S3中的状态文件
echo "=== S3后端初始化完成 ==="
echo "现在您的Terraform状态文件将存储在S3中"
echo "您可以在provider.tf中查看和修改后端配置"