#!/bin/bash

echo "🔍 正在查询所有子网及其占用情况..."

# 获取所有子网ID及名称
subnets=$(vecli vpc DescribeSubnets --RegionId cn-beijing --Output json | jq -r '.Subnets[] | "\(.SubnetId) \(.SubnetName)"')

while IFS= read -r line; do
  subnet_id=$(echo "$line" | awk '{print $1}')
  subnet_name=$(echo "$line" | awk '{print $2}')

  echo "📡 检查子网: $subnet_name ($subnet_id)"

  # 查询子网下的弹性网卡数量
  eni_count=$(vecli ecs DescribeNetworkInterfaces --RegionId cn-beijing --Filters "SubnetId=$subnet_id" --Output json | jq '.NetworkInterfaces | length')

  if [ "$eni_count" -eq 0 ]; then
    echo "✅ 子网空闲，可安全删除"
  else
    echo "⚠️ 子网被占用，绑定 $eni_count 个弹性网卡"
  fi

  echo "----------------------------------"

done <<< "$subnets"

