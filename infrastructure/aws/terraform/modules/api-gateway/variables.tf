# ========================================
# API Gateway Module Variables
# ========================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = ""
}

variable "api_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "Secure AI Chat Proxy API"
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "prod"
}

# ========================================
# Lambda Integration
# ========================================

variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

# ========================================
# API Configuration
# ========================================

variable "endpoint_type" {
  description = "Type of API Gateway endpoint"
  type        = string
  default     = "REGIONAL"
  
  validation {
    condition     = contains(["EDGE", "REGIONAL", "PRIVATE"], var.endpoint_type)
    error_message = "Endpoint type must be EDGE, REGIONAL, or PRIVATE."
  }
}

variable "api_key_source" {
  description = "Source of the API key for requests"
  type        = string
  default     = "HEADER"
  
  validation {
    condition     = contains(["HEADER", "AUTHORIZER"], var.api_key_source)
    error_message = "API key source must be HEADER or AUTHORIZER."
  }
}

variable "binary_media_types" {
  description = "List of binary media types supported by the REST API"
  type        = list(string)
  default     = []
}

variable "minimum_compression_size" {
  description = "Minimum response size to compress for the REST API"
  type        = number
  default     = 1024
  
  validation {
    condition     = var.minimum_compression_size >= 0 && var.minimum_compression_size <= 10485760
    error_message = "Minimum compression size must be between 0 and 10485760 bytes."
  }
}

variable "disable_execute_api_endpoint" {
  description = "Whether to disable the default execute-api endpoint"
  type        = bool
  default     = false
}

# ========================================
# Authorization and Security
# ========================================

variable "authorization_type" {
  description = "Type of authorization used for the method"
  type        = string
  default     = "NONE"
  
  validation {
    condition     = contains(["NONE", "AWS_IAM", "CUSTOM", "COGNITO_USER_POOLS"], var.authorization_type)
    error_message = "Authorization type must be NONE, AWS_IAM, CUSTOM, or COGNITO_USER_POOLS."
  }
}

variable "api_key_required" {
  description = "Whether an API key is required for the method"
  type        = bool
  default     = false
}

variable "cors_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

# ========================================
# Performance and Caching
# ========================================

variable "cache_cluster_enabled" {
  description = "Whether to enable caching for the stage"
  type        = bool
  default     = false
}

variable "cache_cluster_size" {
  description = "Size of the cache cluster"
  type        = string
  default     = "0.5"
  
  validation {
    condition = contains([
      "0.5", "1.6", "6.1", "13.5", "28.4", "58.2", "118", "237"
    ], var.cache_cluster_size)
    error_message = "Cache cluster size must be a valid value."
  }
}

variable "cache_ttl_seconds" {
  description = "Default TTL for cached responses"
  type        = number
  default     = 300
  
  validation {
    condition     = var.cache_ttl_seconds >= 0 && var.cache_ttl_seconds <= 3600
    error_message = "Cache TTL must be between 0 and 3600 seconds."
  }
}

# ========================================
# Throttling
# ========================================

variable "throttle_rate_limit" {
  description = "Throttle rate limit (requests per second)"
  type        = number
  default     = 1000
  
  validation {
    condition     = var.throttle_rate_limit >= 0
    error_message = "Throttle rate limit must be non-negative."
  }
}

variable "throttle_burst_limit" {
  description = "Throttle burst limit"
  type        = number
  default     = 2000
  
  validation {
    condition     = var.throttle_burst_limit >= 0
    error_message = "Throttle burst limit must be non-negative."
  }
}

# ========================================
# Logging and Monitoring
# ========================================

variable "enable_access_logging" {
  description = "Enable access logging for API Gateway"
  type        = bool
  default     = true
}

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

variable "logging_level" {
  description = "Logging level for API Gateway"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["OFF", "ERROR", "INFO"], var.logging_level)
    error_message = "Logging level must be OFF, ERROR, or INFO."
  }
}

variable "enable_detailed_metrics" {
  description = "Enable detailed CloudWatch metrics"
  type        = bool
  default     = true
}

variable "enable_data_trace" {
  description = "Enable data trace logging"
  type        = bool
  default     = false
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for log encryption"
  type        = string
  default     = ""
}

# ========================================
# Custom Domain
# ========================================

variable "custom_domain_name" {
  description = "Custom domain name for the API"
  type        = string
  default     = ""
}

variable "domain_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
  default     = ""
}

variable "domain_hosted_zone_id" {
  description = "Route53 hosted zone ID for the custom domain"
  type        = string
  default     = ""
}

variable "base_path" {
  description = "Base path for the custom domain mapping"
  type        = string
  default     = ""
}

# ========================================
# API Key and Usage Plan
# ========================================

variable "create_api_key" {
  description = "Create an API key"
  type        = bool
  default     = false
}

variable "create_usage_plan" {
  description = "Create a usage plan"
  type        = bool
  default     = false
}

variable "usage_plan_quota_limit" {
  description = "Maximum number of requests per quota period"
  type        = number
  default     = 10000
}

variable "usage_plan_quota_period" {
  description = "Quota period (DAY, WEEK, MONTH)"
  type        = string
  default     = "MONTH"
  
  validation {
    condition     = contains(["DAY", "WEEK", "MONTH"], var.usage_plan_quota_period)
    error_message = "Usage plan quota period must be DAY, WEEK, or MONTH."
  }
}

variable "usage_plan_rate_limit" {
  description = "Usage plan rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "usage_plan_burst_limit" {
  description = "Usage plan burst limit"
  type        = number
  default     = 200
}

# ========================================
# Integration Settings
# ========================================

variable "integration_timeout" {
  description = "Integration timeout in milliseconds"
  type        = number
  default     = 29000
  
  validation {
    condition     = var.integration_timeout >= 50 && var.integration_timeout <= 29000
    error_message = "Integration timeout must be between 50 and 29000 milliseconds."
  }
}

variable "stage_variables" {
  description = "Map of stage variables"
  type        = map(string)
  default     = {}
}

# ========================================
# WAF Integration
# ========================================

variable "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with API Gateway"
  type        = string
  default     = ""
}

# ========================================
# Tags
# ========================================

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}