#!/bin/bash

# 查询Terraform状态变更审计记录
# 使用方法: ./query_terraform_state_audit.sh [table_name] [days] [profile]

set -e

# 默认值
TABLE_NAME=${1:-"terraform-state-audit"}
DAYS=${2:-7}
PROFILE=${3:-"subaccount"}

# 检查AWS CLI是否已安装
if ! command -v aws &> /dev/null; then
    echo "错误: 未找到AWS CLI，请先安装AWS CLI"
    echo "安装指南: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# 检查AWS配置文件是否存在
if ! aws configure list --profile "$PROFILE" &> /dev/null; then
    echo "警告: 未找到AWS配置文件 '$PROFILE'"
    echo "请先配置AWS配置文件:"
    echo "aws configure --profile $PROFILE"
    echo "继续执行可能会失败..."
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 清除可能影响配置文件使用的环境变量
unset AWS_PROFILE


# 计算时间范围
START_DATE=$(date -v -${DAYS}d +"%Y-%m-%dT%H:%M:%S")
END_DATE=$(date +"%Y-%m-%dT%H:%M:%S")

echo "=== 查询Terraform状态变更审计记录 ==="
echo "表名: $TABLE_NAME"
echo "时间范围: 过去${DAYS}天 ($START_DATE 至 $END_DATE)"

# 查询DynamoDB表
echo "正在查询..."
echo "使用配置文件: $PROFILE"
aws dynamodb scan \
    --profile "$PROFILE" \
    --table-name "$TABLE_NAME" \
    --filter-expression "#ts between :start_date and :end_date" \
    --expression-attribute-names '{"#ts":"Timestamp"}' \
    --expression-attribute-values "{\":start_date\":{\"S\":\"$START_DATE\"},\":end_date\":{\"S\":\"$END_DATE\"}}" \
    --query "Items[*].{Time:Timestamp.S,StateFile:StateFileKey.S,EventType:EventType.S,User:UserIdentity.S,UserType:UserType.S,AccountId:AccountId.S}" \
    --output table

echo "=== 查询完成 ==="
echo "提示: 如需查看更多详细信息，请使用AWS控制台访问DynamoDB表"