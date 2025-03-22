# 声明所需的提供商
# 指定Cloudflare提供商的源和版本
# Cloudflare提供商用于管理DNS记录、CDN设置、安全规则等
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare" # 提供商源，格式为 "命名空间/提供商名称"
      version = "~> 4.0"               # 提供商版本，使用兼容性版本约束
    }
  }
}

# 定义本地变量
# 本地变量用于简化配置和提高代码可读性
locals {
  domain = var.domain # 存储域名，如example.com，便于后续引用
}

# 创建DNS记录
# DNS记录用于将域名映射到IP地址或其他资源
# 使用for_each循环创建多个DNS记录，避免重复代码
resource "cloudflare_record" "records" {
  # 使用for_each遍历dns_records列表，创建唯一的键值对
  # 键格式为"记录名_记录类型"，确保每条记录唯一
  for_each = {
    for record in var.dns_records : "${record.name}_${record.type}" => record
  }

  zone_id = var.zone_id            # Cloudflare区域ID，标识域名所在的区域
  name    = each.value.name        # 记录名称，如www、mail等
  content = each.value.value       # 记录值，如IP地址、CNAME目标等
  type    = each.value.type        # 记录类型，如A、CNAME、MX等
  ttl     = lookup(each.value, "ttl", 1) # 生存时间，1表示自动（由Cloudflare管理）
  proxied = lookup(each.value, "proxied", false) # 是否启用Cloudflare代理（CDN、安全防护）
}