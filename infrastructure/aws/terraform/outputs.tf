# Terraform Outputs for Secure AI Chat Proxy

# API Gateway Outputs
output "api_gateway_url" {
  description = "Base URL for API Gateway"
  value       = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}"
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.chat_api.id
}

output "api_gateway_stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.chat_api_stage.stage_name
}

output "custom_domain_url" {
  description = "Custom domain URL (if configured)"
  value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}" : null
}

output "api_endpoints" {
  description = "Available API endpoints"
  value = {
    chat_endpoint    = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}/chat"
    history_endpoint = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}/history"
    health_endpoint  = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}/health"
  }
}

# Lambda Function Outputs
output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.chat_proxy.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.chat_proxy.arn
}

output "lambda_function_version" {
  description = "Latest Lambda function version"
  value       = aws_lambda_function.chat_proxy.version
}

output "lambda_log_group" {
  description = "CloudWatch log group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

# DynamoDB Outputs
output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.chat_sessions.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.chat_sessions.arn
}

output "dynamodb_kms_key_id" {
  description = "KMS key ID for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.key_id
}

output "dynamodb_kms_key_arn" {
  description = "KMS key ARN for DynamoDB encryption"
  value       = aws_kms_key.dynamodb.arn
}

# Security Outputs
output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN (if enabled)"
  value       = var.enable_waf ? aws_wafv2_web_acl.api_protection[0].arn : null
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID (if enabled)"
  value       = var.enable_waf ? aws_wafv2_web_acl.api_protection[0].id : null
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_role_name" {
  description = "Lambda execution role name"
  value       = aws_iam_role.lambda_role.name
}

# Monitoring Outputs
output "cloudwatch_log_groups" {
  description = "CloudWatch log groups created"
  value = {
    lambda_logs     = aws_cloudwatch_log_group.lambda_logs.name
    api_gateway_logs = aws_cloudwatch_log_group.api_gateway_logs.name
  }
}

output "cloudwatch_alarms" {
  description = "CloudWatch alarms created"
  value = {
    lambda_errors       = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
    lambda_duration     = aws_cloudwatch_metric_alarm.lambda_duration.alarm_name
    api_4xx_errors      = aws_cloudwatch_metric_alarm.api_gateway_4xx_errors.alarm_name
    dynamodb_throttles  = aws_cloudwatch_metric_alarm.dynamodb_throttles.alarm_name
  }
}

# Infrastructure Outputs
output "dead_letter_queue_url" {
  description = "Dead letter queue URL"
  value       = aws_sqs_queue.dlq.url
}

output "dead_letter_queue_arn" {
  description = "Dead letter queue ARN"
  value       = aws_sqs_queue.dlq.arn
}

# DNS Outputs
output "route53_record" {
  description = "Route53 record for custom domain (if configured)"
  value = var.custom_domain_name != "" && var.route53_zone_id != "" ? {
    name    = aws_route53_record.custom_domain[0].name
    type    = aws_route53_record.custom_domain[0].type
    zone_id = aws_route53_record.custom_domain[0].zone_id
  } : null
}

output "api_gateway_domain_name" {
  description = "API Gateway domain name configuration (if configured)"
  value = var.custom_domain_name != "" ? {
    domain_name                = aws_api_gateway_domain_name.custom_domain[0].domain_name
    regional_domain_name       = aws_api_gateway_domain_name.custom_domain[0].regional_domain_name
    regional_zone_id          = aws_api_gateway_domain_name.custom_domain[0].regional_zone_id
    certificate_arn           = aws_api_gateway_domain_name.custom_domain[0].regional_certificate_arn
  } : null
}

# Configuration Outputs
output "environment_variables" {
  description = "Lambda environment variables (non-sensitive)"
  value = {
    DYNAMODB_TABLE   = aws_dynamodb_table.chat_sessions.name
    SESSION_TTL_DAYS = var.session_ttl_days
    LOG_LEVEL        = var.log_level
    NODE_ENV         = var.environment
    SERVICE_VERSION  = "1.0.0"
  }
  sensitive = false
}

output "ssm_parameters" {
  description = "SSM parameters created for secure configuration"
  value = {
    anthropic_api_key = aws_ssm_parameter.anthropic_api_key.name
    totp_secret       = aws_ssm_parameter.totp_secret.name
  }
  sensitive = false
}

# Resource Identifiers
output "resource_prefix" {
  description = "Resource prefix used for naming"
  value       = local.resource_prefix
}

output "resource_suffix" {
  description = "Random suffix used for unique naming"
  value       = local.resource_suffix
}

output "deployment_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "deployment_environment" {
  description = "Deployment environment"
  value       = var.environment
}

# Business Domain Configuration
output "primary_domains" {
  description = "Primary business domains for obfuscation"
  value       = var.primary_domains
  sensitive   = false
}

output "backup_domains" {
  description = "Backup business domains"
  value       = var.backup_domains
  sensitive   = false
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (approximate)"
  value = {
    lambda_requests     = "~$0.20 per 1M requests"
    lambda_duration     = "~$0.0000166667 per GB-second"
    api_gateway        = "~$3.50 per 1M requests"
    dynamodb_on_demand = "~$1.25 per 1M read requests, $1.25 per 1M write requests"
    cloudwatch_logs    = "~$0.50 per GB ingested"
    kms_requests       = "~$0.03 per 10K requests"
    waf_requests       = var.enable_waf ? "~$1.00 per 1M requests" : "Not enabled"
  }
}

# Security Configuration Summary
output "security_configuration" {
  description = "Security configuration summary"
  value = {
    encryption_at_rest     = "Enabled (KMS)"
    encryption_in_transit  = "Enabled (TLS 1.3)"
    waf_protection        = var.enable_waf ? "Enabled" : "Disabled"
    xray_tracing          = var.enable_xray_tracing ? "Enabled" : "Disabled"
    point_in_time_recovery = var.enable_point_in_time_recovery ? "Enabled" : "Disabled"
    ssm_secrets           = var.use_ssm_for_secrets ? "Enabled" : "Disabled"
    vpc_isolation         = var.enable_vpc ? "Enabled" : "Disabled"
  }
}

# Deployment Information
output "deployment_info" {
  description = "Deployment information and next steps"
  value = {
    deployment_time    = timestamp()
    terraform_version  = ">=1.5"
    aws_provider_version = "~>5.0"
    next_steps = [
      "Update Postman collection with API Gateway URL",
      "Configure TOTP secret in Google Authenticator",
      "Test health endpoint for connectivity",
      "Run integration tests",
      "Configure domain DNS records (if using custom domain)",
      "Set up monitoring alerts and dashboards"
    ]
  }
}

# Testing Endpoints
output "test_commands" {
  description = "Sample test commands for validation"
  value = {
    health_check = "curl -X GET '${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}/health'"
    
    lambda_test = "aws lambda invoke --function-name ${aws_lambda_function.chat_proxy.function_name} --payload '{\"httpMethod\":\"GET\",\"path\":\"/health\"}' response.json"
    
    dynamodb_test = "aws dynamodb describe-table --table-name ${aws_dynamodb_table.chat_sessions.name}"
  }
}

# Postman Configuration
output "postman_environment" {
  description = "Environment variables for Postman collection"
  value = {
    api_url = "https://${aws_api_gateway_rest_api.chat_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}"
    primary_domain = length(var.primary_domains) > 0 ? var.primary_domains[0] : ""
    backup_domains = join(",", var.backup_domains)
    region = var.aws_region
    environment = var.environment
  }
  sensitive = false
}

# Backup and Recovery Information
output "backup_configuration" {
  description = "Backup and recovery configuration"
  value = {
    point_in_time_recovery = var.enable_point_in_time_recovery
    automated_backups     = var.enable_backup
    backup_retention_days = var.backup_retention_days
    kms_key_deletion_window = var.kms_deletion_window
    disaster_recovery     = var.enable_disaster_recovery
    rto_minutes          = var.rto_minutes
    rpo_minutes          = var.rpo_minutes
  }
}

# Performance Configuration
output "performance_configuration" {
  description = "Performance configuration settings"
  value = {
    lambda_memory_mb     = var.lambda_memory_size
    lambda_timeout_sec   = var.lambda_timeout
    reserved_concurrency = var.reserved_concurrency
    dynamodb_billing_mode = var.use_provisioned_billing ? "PROVISIONED" : "PAY_PER_REQUEST"
    waf_rate_limit       = var.enable_waf ? var.waf_rate_limit : null
  }
}

# Compliance Information
output "compliance_status" {
  description = "Compliance and audit configuration"
  value = {
    compliance_mode    = var.enable_compliance_mode
    audit_logging     = var.enable_audit_logging
    data_residency    = var.data_residency_region != "" ? var.data_residency_region : "Not specified"
    log_retention_days = var.log_retention_days
    encryption_standards = "AES-256, TLS 1.3"
  }
}

# Resource Tags Applied
output "applied_tags" {
  description = "Tags applied to all resources"
  value = merge(local.common_tags, var.additional_tags, {
    CostCenter    = var.cost_center
    Owner         = var.owner
    ContactEmail  = var.contact_email
  })
  sensitive = false
}