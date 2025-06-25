# ========================================
# Core Infrastructure Outputs
# ========================================

output "deployment_id" {
  description = "Unique deployment identifier"
  value       = random_uuid.deployment_id.result
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "name_prefix" {
  description = "Common name prefix for all resources"
  value       = local.name_prefix
}

# ========================================
# Lambda Function Outputs
# ========================================

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.function_arn
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = module.lambda.invoke_arn
}

output "lambda_function_version" {
  description = "Latest published version of the Lambda function"
  value       = module.lambda.function_version
}

output "lambda_function_url" {
  description = "Lambda function URL (if enabled)"
  value       = module.lambda.function_url
  sensitive   = true
}

output "lambda_log_group_name" {
  description = "CloudWatch log group name for Lambda"
  value       = module.lambda.log_group_name
}

# ========================================
# DynamoDB Outputs
# ========================================

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.dynamodb.table_arn
}

output "dynamodb_table_id" {
  description = "ID of the DynamoDB table"
  value       = module.dynamodb.table_id
}

output "dynamodb_table_stream_arn" {
  description = "ARN of the DynamoDB table stream"
  value       = module.dynamodb.table_stream_arn
}

# ========================================
# API Gateway Outputs
# ========================================

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_id
}

output "api_gateway_arn" {
  description = "ARN of the API Gateway"
  value       = module.api_gateway.api_arn
}

output "api_gateway_name" {
  description = "Name of the API Gateway"
  value       = module.api_gateway.api_name
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = module.api_gateway.stage_name
}

output "api_gateway_stage_arn" {
  description = "ARN of the API Gateway stage"
  value       = module.api_gateway.stage_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = module.api_gateway.invoke_url
  sensitive   = true
}

output "api_gateway_deployment_id" {
  description = "ID of the API Gateway deployment"
  value       = module.api_gateway.deployment_id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = module.api_gateway.execution_arn
}

# ========================================
# Custom Domain Outputs (if configured)
# ========================================

output "custom_domain_name" {
  description = "Custom domain name for API Gateway"
  value       = var.custom_domain_name != "" ? var.custom_domain_name : null
}

output "custom_domain_target" {
  description = "Target domain name for custom domain"
  value       = module.api_gateway.domain_name
}

output "custom_domain_hosted_zone_id" {
  description = "Hosted zone ID for custom domain"
  value       = module.api_gateway.hosted_zone_id
}

# ========================================
# Monitoring Outputs
# ========================================

output "cloudwatch_log_groups" {
  description = "CloudWatch log groups created"
  value = {
    lambda      = module.lambda.log_group_name
    api_gateway = module.api_gateway.log_group_name
  }
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "sns_topic_name" {
  description = "SNS topic name for alerts"
  value       = module.monitoring.sns_topic_name
}

# ========================================
# Security Outputs
# ========================================

output "cloudtrail_arn" {
  description = "CloudTrail ARN (if enabled)"
  value       = var.enable_cloudtrail ? aws_cloudtrail.secure_chat_trail[0].arn : null
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail_logs[0].id : null
}

output "iam_role_arn" {
  description = "IAM role ARN for Lambda execution"
  value       = module.lambda.execution_role_arn
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = module.dynamodb.kms_key_id
}

# ========================================
# Backup Outputs
# ========================================

output "backup_vault_name" {
  description = "AWS Backup vault name (if enabled)"
  value       = var.enable_automated_backups ? module.backup[0].vault_name : null
}

output "backup_plan_arn" {
  description = "AWS Backup plan ARN (if enabled)"
  value       = var.enable_automated_backups ? module.backup[0].plan_arn : null
}

# ========================================
# Network Outputs
# ========================================

output "vpc_id" {
  description = "VPC ID (if Lambda deployed in VPC)"
  value       = var.enable_vpc_deployment ? var.vpc_id : null
}

output "subnet_ids" {
  description = "Subnet IDs