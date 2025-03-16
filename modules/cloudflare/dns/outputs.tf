output "record_ids" {
  description = "创建的DNS记录ID列表"
  value       = [for record in cloudflare_record.records : record.id]
}

output "record_names" {
  description = "创建的DNS记录名称列表"
  value       = [for record in cloudflare_record.records : record.name]
}

output "record_values" {
  description = "创建的DNS记录值列表"
  value       = [for record in cloudflare_record.records : record.value]
}