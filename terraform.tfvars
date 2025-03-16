# Cloudflare配置
# 已替换为实际值
cloudflare_zone_id = "your-actual-zone-id" # 在Cloudflare控制面板的「概述」页面右下角找到
domain_name = "example.com"

# 不推荐在此设置API Token，请使用环境变量CLOUDFLARE_API_TOKEN
# export CLOUDFLARE_API_TOKEN="您的API令牌"

# 火山引擎区域配置
region = "cn-shanghai"

# 其他配置
# vpc_base_name = "prod" # 默认为prod
# vpc_cidr = "10.0.0.0/16" # 默认为10.0.0.0/16