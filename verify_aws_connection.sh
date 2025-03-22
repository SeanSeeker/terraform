#!/bin/bash

# 使用方法: ./verify_aws_connection.sh [profile]

# 默认值
PROFILE=${1:-"subaccount"}

echo "=== AWS连接验证脚本 ==="
echo "使用配置文件: $PROFILE"

# 检查AWS CLI是否已安装
if ! command -v aws &> /dev/null; then
    echo "错误: 未找到AWS CLI，请先安装AWS CLI"
    echo "安装指南: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# 检查AWS凭证是否已配置
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "警告: 未设置AWS凭证环境变量"
    echo "请设置以下环境变量:"
    echo "export AWS_ACCESS_KEY_ID=您的访问密钥ID"
    echo "export AWS_SECRET_ACCESS_KEY=您的访问密钥密码"
    echo "继续执行可能会失败..."
fi

echo "\n正在验证AWS凭证..."

# 尝试获取调用者身份信息
echo "\n1. 尝试获取AWS身份信息:"
if aws sts get-caller-identity --profile "$PROFILE"; then
    echo "✅ 成功获取身份信息，AWS凭证有效"
else
    echo "❌ 无法获取身份信息，AWS凭证可能无效"
    exit 1
fi

# 尝试列出S3存储桶
echo "\n2. 尝试列出S3存储桶:"
if aws s3 ls --profile "$PROFILE"; then
    echo "✅ 成功列出S3存储桶"
else
    echo "❌ 无法列出S3存储桶，请检查权限"
fi

# 检查Terraform AWS Provider配置
echo "\n3. Terraform AWS Provider配置检查:"
echo "当前配置的AWS区域: $(grep -A1 'provider "aws"' /Users/sean/Code/terraform/provider.tf | grep region | cut -d'=' -f2 | tr -d ' ')"

echo "\n验证完成。如果上述测试都成功，则表明您可以正常连接到AWS。"