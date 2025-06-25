# ========================================
# Lambda Module Variables
# ========================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = ""
}

variable "source_path" {
  description = "Path to the Lambda source code"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
  
  validation {
    condition = contains([
      "nodejs18.x", "nodejs20.x", "python3.9", "python3.10", "python3.11",
      "java11", "java17", "dotnet6", "go1.x", "provided.al2"
    ], var.runtime)
    error_message = "Runtime must be a valid Lambda runtime."
  }
}

variable "architecture" {
  description = "Instruction set architecture for the Lambda function"
  type        = string
  default     = "arm64"
  
  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "Architecture must be either x86_64 or arm64."
  }
}

variable "timeout" {
  description = "Amount of time your Lambda function has to run in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda function can use at runtime"
  type        = number
  default     = 256
  
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }
}

variable "ephemeral_storage_size" {
  description = "Amount of ephemeral storage (/tmp) in MB"
  type        = number
  default     = 512
  
  validation {
    condition     = var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240
    error_message = "Ephemeral storage size must be between 512 and 10240 MB."
  }
}

variable "environment_variables" {
  description = "Map of environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "package_type" {
  description = "Lambda deployment package type"
  type        = string
  default     = "Zip"
  
  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "Package type must be either Zip or Image."
  }
}

variable "publish_version" {
  description = "Whether to publish creation/change as new Lambda Function Version"
  type        = bool
  default     = false
}

# ========================================
# VPC Configuration
# ========================================

variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    vpc_id     = optional(string)
    subnet_ids = optional(list(string))
  })
  default = {
    vpc_id     = null
    subnet_ids = null
  }
}

# ========================================
# Concurrency and Performance
# ========================================

variable "reserved_concurrency" {
  description = "Amount of reserved concurrent executions for this Lambda function"
  type        = number
  default     = -1
  
  validation {
    condition     = var.reserved_concurrency >= -1
    error_message = "Reserved concurrency must be -1 (unreserved) or >= 0."
  }
}

variable "provisioned_concurrency" {
  description = "Amount of provisioned concurrency for this Lambda function"
  type        = number
  default     = 0
  
  validation {
    condition     = var.provisioned_concurrency >= 0
    error_message = "Provisioned concurrency must be >= 0."
  }
}

# ========================================
# Function URL Configuration
# ========================================

variable "enable_function_url" {
  description = "Enable Lambda Function URL"
  type        = bool
  default     = false
}

variable "function_url_auth_type" {
  description = "Type of authentication for Function URL"
  type        = string
  default     = "AWS_IAM"
  
  validation {
    condition     = contains(["AWS_IAM", "NONE"], var.function_url_auth_type)
    error_message = "Function URL auth type must be AWS_IAM or NONE."
  }
}

variable "function_url_cors" {
  description = "CORS configuration for Function URL"
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), [])
    allow_methods     = optional(list(string), ["*"])
    allow_origins     = optional(list(string), ["*"])
    expose_headers    = optional(list(string), [])
    max_age          = optional(number, 86400)
  })
  default = null
}

# ========================================
# Dead Letter Queue and Async Config
# ========================================

variable "dead_letter_queue_arn" {
  description = "ARN of the dead letter queue"
  type        = string
  default     = ""
}

variable "maximum_event_age" {
  description = "Maximum age of a request that Lambda sends to a function for processing"
  type        = number
  default     = 21600
  
  validation {
    condition     = var.maximum_event_age >= 60 && var.maximum_event_age <= 21600
    error_message = "Maximum event age must be between 60 and 21600 seconds."
  }
}

variable "maximum_retry_attempts" {
  description = "Maximum number of times to retry when the function returns an error"
  type        = number
  default     = 2
  
  validation {
    condition     = var.maximum_retry_attempts >= 0 && var.maximum_retry_attempts <= 2
    error_message = "Maximum retry attempts must be between 0 and 2."
  }
}

variable "async_config" {
  description = "Async invoke configuration"
  type = object({
    on_success_arn = optional(string, "")
    on_failure_arn = optional(string, "")
  })
  default = {
    on_success_arn = ""
    on_failure_arn = ""
  }
}

# ========================================
# Alias Configuration
# ========================================

variable "create_alias" {
  description = "Whether to create an alias for the Lambda function"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Name for the alias"
  type        = string
  default     = "live"
}

variable "alias_routing_config" {
  description = "Routing configuration for the alias"
  type = object({
    additional_version_weights = optional(map(number))
  })
  default = {
    additional_version_weights = null
  }
}

# ========================================
# IAM and Security
# ========================================

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = ""
}

variable "enable_secrets_manager_access" {
  description = "Enable access to AWS Secrets Manager"
  type        = bool
  default     = false
}

# ========================================
# Monitoring and Observability
# ========================================

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
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

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "error_alarm_threshold" {
  description = "Threshold for error alarm"
  type        = number
  default     = 5
}

variable "duration_alarm_threshold" {
  description = "Threshold for duration alarm (milliseconds)"
  type        = number
  default     = 10000
}

variable "throttle_alarm_threshold" {
  description = "Threshold for throttle alarm"
  type        = number
  default     = 5
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

# ========================================
# EFS Configuration
# ========================================

variable "efs_config" {
  description = "EFS configuration for Lambda function"
  type = object({
    access_point_arn  = optional(string, "")
    local_mount_path  = optional(string, "/mnt/efs")
  })
  default = {
    access_point_arn = ""
    local_mount_path = "/mnt/efs"
  }
}

# ========================================
# Container Image Configuration
# ========================================

variable "image_config" {
  description = "Container image configuration"
  type = object({
    command           = optional(list(string))
    entry_point       = optional(list(string))
    working_directory = optional(string)
  })
  default = {
    command           = null
    entry_point       = null
    working_directory = null
  }
}

# ========================================
# Lambda Layers
# ========================================

variable "layers" {
  description = "List of Lambda Layer Version ARNs to attach to the function"
  type        = list(string)
  default     = []
}

variable "create_layer" {
  description = "Whether to create a Lambda layer"
  type        = bool
  default     = false
}

variable "layer_filename" {
  description = "Path to the layer zip file"
  type        = string
  default     = ""
}

variable "layer_source_code_hash" {
  description = "Source code hash for the layer"
  type        = string
  default     = ""
}

# ========================================
# Event Source Mappings
# ========================================

variable "dynamodb_stream_arn" {
  description = "ARN of the DynamoDB stream"
  type        = string
  default     = ""
}

variable "stream_starting_position" {
  description = "Position in the stream where Lambda starts reading"
  type        = string
  default     = "LATEST"
  
  validation {
    condition     = contains(["TRIM_HORIZON", "LATEST"], var.stream_starting_position)
    error_message = "Stream starting position must be TRIM_HORIZON or LATEST."
  }
}

variable "stream_batch_size" {
  description = "Maximum number of records in each batch"
  type        = number
  default     = 10
  
  validation {
    condition     = var.stream_batch_size >= 1 && var.stream_batch_size <= 1000
    error_message = "Stream batch size must be between 1 and 1000."
  }
}

variable "stream_filter_criteria" {
  description = "Filter criteria for the event source mapping"
  type = object({
    filters = list(object({
      pattern = string
    }))
  })
  default = null
}

# ========================================
# Lambda Permissions and Integrations
# ========================================

variable "allow_api_gateway_invoke" {
  description = "Allow API Gateway to invoke this Lambda function"
  type        = bool
  default     = true
}

variable "api_gateway_source_arn" {
  description = "Source ARN for API Gateway invocation permission"
  type        = string
  default     = ""
}

variable "allow_cloudwatch_events_invoke" {
  description = "Allow CloudWatch Events to invoke this Lambda function"
  type        = bool
  default     = false
}

variable "allow_s3_invoke" {
  description = "Allow S3 to invoke this Lambda function"
  type        = bool
  default     = false
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Lambda permission"
  type        = string
  default     = ""
}

variable "allow_sns_invoke" {
  description = "Allow SNS to invoke this Lambda function"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for Lambda permission"
  type        = string
  default     = ""
}

# ========================================
# Lambda Insights and Enhanced Monitoring
# ========================================

variable "enable_lambda_insights" {
  description = "Enable AWS Lambda Insights"
  type        = bool
  default     = false
}

variable "enable_custom_metrics" {
  description = "Enable custom CloudWatch metrics"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Create CloudWatch dashboard for the Lambda function"
  type        = bool
  default     = false
}

# ========================================
# Tags
# ========================================

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}