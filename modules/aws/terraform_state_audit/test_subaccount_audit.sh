#!/bin/bash

# 测试子账号是否正确记录在Terraform状态审计中
# 使用方法: ./test_subaccount_audit.sh [profile] [table_name]

set -e

# 默认值
PROFILE=${1:-"subaccount"}
TABLE_NAME=${2:-"terraform-state-audit"}

echo "=== 测试子账号Terraform状态审计 ==="
echo "使用配置文件: $PROFILE"
echo "审计表名: $TABLE_NAME"

# 检查AWS CLI是否已安装
if ! command -v aws &> /dev/null; then
    echo "错误: 未找到AWS CLI，请先安装AWS CLI"
    echo "安装指南: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# 检查是否已配置AWS配置文件
if ! aws configure list --profile "$PROFILE" &> /dev/null; then
    echo "错误: 未找到AWS配置文件 '$PROFILE'"
    echo "请先配置AWS配置文件:"
    echo "aws configure --profile $PROFILE"
    exit 1
fi

echo "\n步骤1: 使用子账号进行小的Terraform更改"
echo "提示: 请使用子账号凭证执行以下操作:"
echo "1. 修改任意Terraform配置文件"
echo "2. 运行 'terraform apply'"
echo "3. 等待几分钟让Lambda函数处理事件"

read -p "是否已完成Terraform更改? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "测试已取消"
    exit 0
fi

echo "\n步骤2: 查询最新的审计记录"

# 获取当前时间和24小时前的时间
END_DATE=$(date +"%Y-%m-%dT%H:%M:%S")
START_DATE=$(date -v -2d +"%Y-%m-%dT%H:%M:%S") # 24小时前

echo "查询时间范围: $START_DATE 至 $END_DATE"
echo "正在查询..."

# 查询DynamoDB表获取最新记录
aws dynamodb scan \
    --profile "$PROFILE" \
    --table-name "$TABLE_NAME" \
    --filter-expression "#ts between :start_date and :end_date" \
    --expression-attribute-names '{"#ts":"Timestamp"}' \
    --expression-attribute-values "{\":start_date\":{\"S\":\"$START_DATE\"},\":end_date\":{\"S\":\"$END_DATE\"}}" \
    --query "Items[*].{Time:Timestamp.S,StateFile:StateFileKey.S,EventType:EventType.S,User:UserIdentity.S,UserType:UserType.S,AccountId:AccountId.S}" \
    --output table

echo "\n=== 测试完成 ==="
echo "检查上述输出中的'User'列是否显示正确的子账号信息"
echo "如果显示为'未知'，请检查Lambda函数日志以获取更多信息"