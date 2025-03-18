#!/bin/bash

echo "🔥 开始销毁旧的非模块化网络资源..."

terraform destroy \
  -target=volcengine_vpc.main \
  -target=volcengine_route_table.main \
  -target=volcengine_subnet.subnets[0] \
  -target=volcengine_subnet.subnets[1] \
  -target=volcengine_subnet.subnets[2] \
  -target=volcengine_subnet.subnets[3] \
  -auto-approve

echo "✅ 旧资源销毁完成，以下为当前 Terraform 状态："
terraform state list

echo "💡 建议执行一次 terraform plan 检查当前资源状态"
