# ========================================
# DynamoDB Module Outputs
# ========================================

output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.chat_sessions.name
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.chat_sessions.id
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.chat_sessions.arn
}

output "table_stream_arn" {
  description = "ARN of the DynamoDB table stream"
  value       = aws_dynamodb_table.chat_sessions.stream_arn
}

output "table_stream_label" {
  description = "Timestamp of the DynamoDB table stream"
  value       = aws_dynamodb_table.chat_sessions.stream_label
}

output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = var.enable_custom_kms_key ? aws_kms_key.dynamodb[0].key_id : "alias/aws/dynamodb"
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = var.enable_custom_kms_key ? aws_kms_key.dynamodb[0].arn : null
}

output "kms_alias_name" {
  description = "Alias name of the KMS key"
  value       = var.enable_custom_kms_key ? aws_kms_alias.dynamodb[0].name : null
}

output "autoscaling_read_target_id" {
  description = "Resource ID of the read capacity autoscaling target"
  value       = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_target.read[0].id : null
}

output "autoscaling_write_target_id" {
  description = "Resource ID of the write capacity autoscaling target"
  value       = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_target.write[0].id : null
}

output "cloudwatch_alarms" {
  description = "CloudWatch alarms created for the table"
  value = var.enable_cloudwatch_alarms ? {
    read_throttle = {
      name = aws_cloudwatch_metric_alarm.read_throttle[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.read_throttle[0].arn
    }
    write_throttle = {
      name = aws_cloudwatch_metric_alarm.write_throttle[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.write_throttle[0].arn
    }
    high_read_capacity = var.billing_mode == "PROVISIONED" ? {
      name = aws_cloudwatch_metric_alarm.consumed_read_capacity[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.consumed_read_capacity[0].arn
    } : null
    high_write_capacity = var.billing_mode == "PROVISIONED" ? {
      name = aws_cloudwatch_metric_alarm.consumed_write_capacity[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.consumed_write_capacity[0].arn
    } : null
  } : {}
}

output "global_secondary_indexes" {
  description = "Global Secondary Indexes of the table"
  value = {
    user_role_index = {
      name      = "UserRoleIndex"
      hash_key  = "userId"
      range_key = "role"
    }
    role_timestamp_index = {
      name      = "RoleTimestampIndex"
      hash_key  = "role"
      range_key = "timestamp"
    }
  }
}

output "table_configuration" {
  description = "Complete table configuration"
  value = {
    name                    = aws_dynamodb_table.chat_sessions.name
    arn                     = aws_dynamodb_table.chat_sessions.arn
    billing_mode           = aws_dynamodb_table.chat_sessions.billing_mode
    read_capacity          = aws_dynamodb_table.chat_sessions.read_capacity
    write_capacity         = aws_dynamodb_table.chat_sessions.write_capacity
    point_in_time_recovery = aws_dynamodb_table.chat_sessions.point_in_time_recovery[0].enabled
    server_side_encryption = {
      enabled   = aws_dynamodb_table.chat_sessions.server_side_encryption[0].enabled
      kms_key_id = var.enable_custom_kms_key ? aws_kms_key.dynamodb[0].arn : null
    }
    ttl = {
      attribute_name = aws_dynamodb_table.chat_sessions.ttl[0].attribute_name
      enabled       = aws_dynamodb_table.chat_sessions.ttl[0].enabled
    }
    stream_enabled    = aws_dynamodb_table.chat_sessions.stream_enabled
    stream_view_type  = aws_dynamodb_table.chat_sessions.stream_view_type
  }
}