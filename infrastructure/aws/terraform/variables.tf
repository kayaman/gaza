# ========================================
# Core Infrastructure Variables
# ========================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid region identifier."
  }
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "secure-ai-chat-proxy"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "created_by" {
  description = "Who created this infrastructure (for tagging)"
  type        = string
  default     = "terraform"
}

variable "cost_center" {
  description = "Cost center for billing (for tagging)"
  type        = string
  default     = "engineering"
}

# ========================================
# Terraform State Management
# ========================================

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state storage"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.terraform_state_bucket))
    error_message = "S3 bucket name must be valid."
  }
}

variable "terraform_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}

# ========================================
# Security Configuration
# ========================================

variable "anthropic_api_key" {
  description = "Anthropic API key for Claude access"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.anthropic_api_key) > 10
    error_message = "Anthropic API key must be provided."
  }
}

variable "totp_secret" {
  description = "Base32 encoded TOTP secret for encryption"
  type        = string
  sensitive   = true
  
  validation {
    condition     = can(regex("^[A-Z2-7]+$", var.totp_secret)) && length(var.totp_secret) >= 16
    error_message = "TOTP secret must be a valid base32 string of at least 16 characters."
  }
}

variable "session_ttl_days" {
  description = "Number of days before chat sessions expire"
  type        = number
  default     = 30
  
  validation {
    condition     = var.session_ttl_days >= 1 && var.session_ttl_days <= 365
    error_message = "Session TTL must be between 1 and 365 days."
  }
}

# ========================================
# Lambda Configuration
# ========================================

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "secure-chat-proxy"
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "nodejs18.x"
  
  validation {
    condition     = contains(["nodejs18.x", "nodejs20.x"], var.lambda_runtime)
    error_message = "Lambda runtime must be nodejs18.x or nodejs20.x."
  }
}

variable "lambda_source_path" {
  description = "Path to Lambda source code"
  type        = string
  default     = "../../../backend/lambda"
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "src/index.handler"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
  
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for Lambda function"
  type        = number
  default     = 100
  
  validation {
    condition     = var.lambda_reserved_concurrency >= 0
    error_message = "Reserved concurrency must be non-negative."
  }
}

variable "lambda_provisioned_concurrency" {
  description = "Provisioned concurrency for Lambda function"
  type        = number
  default     = 5
  
  validation {
    condition     = var.lambda_provisioned_concurrency >= 0
    error_message = "Provisioned concurrency must be non-negative."
  }
}

# ========================================
# DynamoDB Configuration
# ========================================

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "encrypted-chat-sessions"
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
  
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "Billing mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units (for PROVISIONED billing)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units (for PROVISIONED billing)"
  type        = number
  default     = 5
}

variable "enable_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery"
  type        = bool
  default     = true
}

# ========================================
# API Gateway Configuration
# ========================================

variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "secure-chat-api"
}

variable "api_gateway_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "Secure AI Chat Proxy API"
}

variable "api_gateway_stage" {
  description = "API Gateway deployment stage"
  type        = string
  default     = "prod"
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 2000
}

variable "enable_api_access_logging" {
  description = "Enable API Gateway access logging"
  type        = bool
  default     = true
}

variable "api_cors_origins" {
  description = "Allowed CORS origins for API Gateway"
  type        = list(string)
  default     = ["*"]
}

# ========================================
# Domain Configuration
# ========================================

variable "custom_domain_name" {
  description = "Custom domain name for API Gateway"
  type        = string
  default     = ""
}

variable "domain_certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = ""
}

variable "domain_hosted_zone_id" {
  description = "Route53 hosted zone ID for custom domain"
  type        = string
  default     = ""
}

# ========================================
# Monitoring & Alerting Configuration
# ========================================

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARN, ERROR."
  }
}

variable "sns_topic_name" {
  description = "SNS topic name for alerts"
  type        = string
  default     = "secure-chat-alerts"
}

variable "alert_email_endpoints" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# ========================================
# Monitoring Thresholds
# ========================================

variable "lambda_error_threshold" {
  description = "Lambda error rate threshold for alerts (%)"
  type        = number
  default     = 5
}

variable "lambda_duration_threshold" {
  description = "Lambda duration threshold for alerts (ms)"
  type        = number
  default     = 10000
}

variable "api_4xx_error_threshold" {
  description = "API Gateway 4xx error threshold for alerts (%)"
  type        = number
  default     = 10
}

variable "api_5xx_error_threshold" {
  description = "API Gateway 5xx error threshold for alerts (%)"
  type        = number
  default     = 1
}

variable "totp_failure_threshold" {
  description = "TOTP validation failure threshold for alerts"
  type        = number
  default     = 50
}

variable "dynamodb_throttle_threshold" {
  description = "DynamoDB throttle threshold for alerts"
  type        = number
  default     = 5
}

# ========================================
# Security & Compliance
# ========================================

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty for threat detection"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable WAF for API Gateway protection"
  type        = bool
  default     = false
}

# ========================================
# Backup & Disaster Recovery
# ========================================

variable "enable_automated_backups" {
  description = "Enable automated DynamoDB backups"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 2 AM
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = false
}

variable "backup_region" {
  description = "Secondary region for backup replication"
  type        = string
  default     = "us-west-2"
}

# ========================================
# Development & Testing
# ========================================

variable "enable_debug_logging" {
  description = "Enable detailed debug logging"
  type        = bool
  default     = false
}

variable "enable_local_development" {
  description = "Enable local development features"
  type        = bool
  default     = false
}

variable "allowed_source_ips" {
  description = "Allowed source IP addresses (for development)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ========================================
# Cost Optimization
# ========================================

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "lambda_architecture" {
  description = "Lambda architecture (x86_64 or arm64)"
  type        = string
  default     = "arm64"
  
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "Architecture must be x86_64 or arm64."
  }
}

variable "enable_resource_tagging" {
  description = "Enable comprehensive resource tagging"
  type        = bool
  default     = true
}

# ========================================
# Feature Flags
# ========================================

variable "enable_api_key_authentication" {
  description = "Enable API key authentication"
  type        = bool
  default     = false
}

variable "enable_cognito_authentication" {
  description = "Enable Cognito user pool authentication"
  type        = bool
  default     = false
}

variable "enable_vpc_deployment" {
  description = "Deploy Lambda in VPC for additional security"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for Lambda deployment (if enable_vpc_deployment is true)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda deployment"
  type        = list(string)
  default     = []
}

variable "enable_custom_kms_key" {
  description = "Use custom KMS key for encryption"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "Custom KMS key ID for encryption"
  type        = string
  default     = ""
}