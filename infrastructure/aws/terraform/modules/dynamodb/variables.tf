# ========================================
# DynamoDB Module Variables
# ========================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = ""
}

variable "billing_mode" {
  description = "Controls how you are charged for read and write throughput"
  type        = string
  default     = "PAY_PER_REQUEST"
  
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "Billing mode must be either PROVISIONED or PAY_PER_REQUEST."
  }
}

variable "read_capacity" {
  description = "Number of read units for this table"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Number of write units for this table"
  type        = number
  default     = 5
}

variable "gsi_read_capacity" {
  description = "Read capacity for GSI"
  type        = number
  default     = 5
}

variable "gsi_write_capacity" {
  description = "Write capacity for GSI"
  type        = number
  default     = 5
}

variable "ttl_attribute" {
  description = "Name of the table attribute to store the TTL timestamp"
  type        = string
  default     = "ttl"
}

variable "point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "enable_streams" {
  description = "Enable DynamoDB streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "When an item in the table is modified, what is written to the stream"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
  
  validation {
    condition = contains([
      "KEYS_ONLY",
      "NEW_IMAGE",
      "OLD_IMAGE",
      "NEW_AND_OLD_IMAGES"
    ], var.stream_view_type)
    error_message = "Stream view type must be one of: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
  }
}

variable "enable_autoscaling" {
  description = "Enable auto scaling for provisioned capacity"
  type        = bool
  default     = true
}

variable "autoscaling_read_min" {
  description = "Minimum read capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_read_max" {
  description = "Maximum read capacity for auto scaling"
  type        = number
  default     = 100
}

variable "autoscaling_read_target" {
  description = "Target utilization for read capacity auto scaling"
  type        = number
  default     = 70.0
}

variable "autoscaling_write_min" {
  description = "Minimum write capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_write_max" {
  description = "Maximum write capacity for auto scaling"
  type        = number
  default     = 100
}

variable "autoscaling_write_target" {
  description = "Target utilization for write capacity auto scaling"
  type        = number
  default     = 70.0
}

variable "enable_custom_kms_key" {
  description = "Enable custom KMS key for encryption"
  type        = bool
  default     = false
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

variable "replica_regions" {
  description = "List of regions for DynamoDB global tables"
  type        = list(string)
  default     = []
}

variable "enable_contributor_insights" {
  description = "Enable DynamoDB Contributor Insights"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for DynamoDB"
  type        = bool
  default     = true
}

variable "read_throttle_threshold" {
  description = "Threshold for read throttle alarm"
  type        = number
  default     = 5
}

variable "write_throttle_threshold" {
  description = "Threshold for write throttle alarm"
  type        = number
  default     = 5
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}