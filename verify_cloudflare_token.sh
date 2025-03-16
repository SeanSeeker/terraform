#!/bin/bash

# 验证Cloudflare API Token是否配置正确的脚本

# 检查环境变量是否设置
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "错误: CLOUDFLARE_API_TOKEN 环境变量未设置"
  echo "请使用以下命令设置: export CLOUDFLARE_API_TOKEN=\"您的API令牌\""
  exit 1
fi

# 使用curl调用Cloudflare API验证Token
echo "正在验证Cloudflare API Token..."
response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json")

# 检查响应
if echo "$response" | grep -q '"success":true'; then
  echo "✅ API Token验证成功! 您的Token配置正确且有效。"
  
  # 提取Token信息
  status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d '"' -f 4)
  echo "Token状态: $status"
  
  # 获取区域列表以进一步验证权限
  echo "\n正在获取您可访问的区域列表..."
  zones=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
       -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
       -H "Content-Type: application/json")
  
  if echo "$zones" | grep -q '"success":true'; then
    count=$(echo "$zones" | grep -o '"count":[0-9]*' | cut -d ':' -f 2)
    echo "您有权限访问 $count 个区域"
    
    # 显示区域名称和ID
    echo "\n区域列表:"
    echo "$zones" | grep -o '"name":"[^"]*","id":"[^"]*"' | while read line; do
      name=$(echo "$line" | grep -o '"name":"[^"]*"' | cut -d '"' -f 4)
      id=$(echo "$line" | grep -o '"id":"[^"]*"' | cut -d '"' -f 4)
      echo "- $name (ID: $id)"
    done
  else
    echo "⚠️ 无法获取区域列表，可能是权限不足"
    echo "错误信息: $(echo "$zones" | grep -o '"message":"[^"]*"' | cut -d '"' -f 4)"
  fi
else
  echo "❌ API Token验证失败!"
  echo "错误信息: $(echo "$response" | grep -o '"message":"[^"]*"' | cut -d '"' -f 4)"
  exit 1
fi