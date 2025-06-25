# Terraform Variables for Secure AI Chat Proxy

# Basic Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "secure-ai-chat-proxy"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# API Configuration
variable "anthropic_api_key" {
  description = "Anthropic API key for Claude access"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.anthropic_api_key) > 50
    error_message = "Anthropic API key must be provided and valid."
  }
}

variable "totp_secret" {
  description = "Base32 encoded TOTP secret"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.totp_secret) >= 16
    error_message = "TOTP secret must be at least 16 characters long."
  }
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 10 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 10 and 900 seconds."
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

variable "log_level" {
  description = "Log level for Lambda function"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["ERROR", "WARN", "INFO", "DEBUG", "TRACE"], var.log_level)
    error_message = "Log level must be one of: ERROR, WARN, INFO, DEBUG, TRACE."
  }
}

# DynamoDB Configuration
variable "session_ttl_days" {
  description = "Number of days to retain session data"
  type        = number
  default     = 30

  validation {
    condition     = var.session_ttl_days >= 1 && var.session_ttl_days <= 365
    error_message = "Session TTL must be between 1 and 365 days."
  }
}

variable "enable_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery"
  type        = bool
  default     = true
}

# API Gateway Configuration
variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.api_stage_name))
    error_message = "API stage name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "custom_domain_name" {
  description = "Custom domain name for API Gateway"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for custom domain"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for custom domain"
  type        = string
  default     = ""
}

# Security Configuration
variable "enable_waf" {
  description = "Enable WAF protection for API Gateway"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes per IP)"
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF rate limit must be between 100 and 20,000,000."
  }
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for country in var.blocked_countries : can(regex("^[A-Z]{2}$", country))
    ])
    error_message = "Country codes must be valid ISO 3166-1 alpha-2 codes (e.g., 'US', 'CN')."
  }
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = ""
}

# Advanced Configuration
variable "use_ssm_for_secrets" {
  description = "Use AWS Systems Manager Parameter Store for secrets"
  type        = bool
  default     = false
}

variable "create_lambda_layer" {
  description = "Create a Lambda layer for dependencies"
  type        = bool
  default     = false
}

variable "enable_scheduled_cleanup" {
  description = "Enable scheduled cleanup of expired data"
  type        = bool
  default     = true
}

variable "cleanup_schedule_expression" {
  description = "CloudWatch Events schedule expression for cleanup"
  type        = string
  default     = "rate(1 day)"

  validation {
    condition = can(regex("^(rate\\(|cron\\()", var.cleanup_schedule_expression))
    error_message = "Schedule expression must be a valid CloudWatch Events expression."
  }
}

# Network Configuration
variable "enable_vpc" {
  description = "Deploy Lambda function in VPC"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for Lambda deployment"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for Lambda deployment"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for Lambda function"
  type        = list(string)
  default     = []
}

# Backup and Recovery
variable "enable_backup" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

# Performance Configuration
variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units (only for provisioned billing)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units (only for provisioned billing)"
  type        = number
  default     = 5
}

variable "use_provisioned_billing" {
  description = "Use provisioned billing mode for DynamoDB"
  type        = bool
  default     = false
}

# Development Configuration
variable "enable_debug_mode" {
  description = "Enable debug mode for development"
  type        = bool
  default     = false
}

variable "allowed_origins" {
  description = "Allowed CORS origins for API Gateway"
  type        = list(string)
  default     = ["*"]
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "reserved_concurrency" {
  description = "Reserved concurrency for Lambda function"
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrency == -1 || var.reserved_concurrency >= 0
    error_message = "Reserved concurrency must be -1 (no limit) or >= 0."
  }
}

# Multi-Region Configuration
variable "enable_multi_region" {
  description = "Enable multi-region deployment"
  type        = bool
  default     = false
}

variable "backup_regions" {
  description = "List of backup regions for multi-region deployment"
  type        = list(string)
  default     = []
}

# Business Domain Configuration
variable "primary_domains" {
  description = "List of primary business domains for obfuscation"
  type        = list(string)
  default = [
    "api.consulting-metrics.com",
    "webhook.project-sync.net",
    "analytics.performance-data.org"
  ]
}

variable "backup_domains" {
  description = "List of backup business domains"
  type        = list(string)
  default = [
    "sync.document-workflow.com",
    "reporting.business-intelligence.net"
  ]
}

# Compliance Configuration
variable "enable_compliance_mode" {
  description = "Enable compliance features (GDPR, SOC2, etc.)"
  type        = bool
  default     = false
}

variable "data_residency_region" {
  description = "Required data residency region for compliance"
  type        = string
  default     = ""
}

variable "enable_audit_logging" {
  description = "Enable detailed audit logging"
  type        = bool
  default     = false
}

# Disaster Recovery
variable "enable_disaster_recovery" {
  description = "Enable disaster recovery features"
  type        = bool
  default     = false
}

variable "rto_minutes" {
  description = "Recovery Time Objective in minutes"
  type        = number
  default     = 60

  validation {
    condition     = var.rto_minutes >= 5 && var.rto_minutes <= 1440
    error_message = "RTO must be between 5 minutes and 24 hours."
  }
}

variable "rpo_minutes" {
  description = "Recovery Point Objective in minutes"
  type        = number
  default     = 15

  validation {
    condition     = var.rpo_minutes >= 1 && var.rpo_minutes <= 1440
    error_message = "RPO must be between 1 minute and 24 hours."
  }
}

# Testing Configuration
variable "enable_chaos_engineering" {
  description = "Enable chaos engineering features for testing"
  type        = bool
  default     = false
}

variable "test_failure_rate" {
  description = "Artificial failure rate for chaos testing (0.0-1.0)"
  type        = number
  default     = 0.0

  validation {
    condition     = var.test_failure_rate >= 0.0 && var.test_failure_rate <= 1.0
    error_message = "Test failure rate must be between 0.0 and 1.0."
  }
}

# Resource Tagging
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = ""
}

variable "contact_email" {
  description = "Contact email for the resources"
  type        = string
  default     = ""

  validation {
    condition = var.contact_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.contact_email))
    error_message = "Contact email must be a valid email address."
  }
}