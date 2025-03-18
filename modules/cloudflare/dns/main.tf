terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# 定义本地变量
locals {
  domain = var.domain
}

# 创建DNS记录
resource "cloudflare_record" "records" {
  for_each = {
    for record in var.dns_records : "${record.name}_${record.type}" => record
  }
  
  zone_id  = var.zone_id
  name     = each.value.name
  content  = each.value.value
  type     = each.value.type
  ttl      = lookup(each.value, "ttl", 1) # 1 = 自动
  proxied  = lookup(each.value, "proxied", false)
}