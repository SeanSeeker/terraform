# 输出VPC和子网信息，供其他模块使用

output "vpc_id" {
  description = "创建的VPC ID"
  value       = volcengine_vpc.main.id
}

output "vpc_name" {
  description = "创建的VPC名称"
  value       = volcengine_vpc.main.vpc_name
}

output "subnet_ids" {
  description = "创建的所有子网ID列表"
  value       = volcengine_subnet.subnets[*].id
}

output "subnet_names" {
  description = "创建的所有子网名称列表"
  value       = volcengine_subnet.subnets[*].subnet_name
}

output "route_table_id" {
  description = "创建的路由表ID"
  value       = volcengine_route_table.main.id
}