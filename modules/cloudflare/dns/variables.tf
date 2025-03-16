variable "zone_id" {
  description = "Cloudflare区域ID"
  type        = string
}

variable "domain" {
  description = "域名"
  type        = string
}

variable "dns_records" {
  description = "DNS记录列表"
  type = list(object({
    name    = string
    value   = string
    type    = string
    ttl     = optional(number, 1)
    proxied = optional(bool, false)
  }))
}