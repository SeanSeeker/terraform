output "cloudtrail_arn" {
  description = "创建的CloudTrail跟踪的ARN"
  value       = aws_cloudtrail.terraform_state_trail.arn
}

output "lambda_function_arn" {
  description = "创建的Lambda函数的ARN"
  value       = aws_lambda_function.state_change_processor.arn
}

output "dynamodb_table_name" {
  description = "创建的DynamoDB审计表的名称"
  value       = aws_dynamodb_table.terraform_state_audit.name
}

output "dynamodb_table_arn" {
  description = "创建的DynamoDB审计表的ARN"
  value       = aws_dynamodb_table.terraform_state_audit.arn
}