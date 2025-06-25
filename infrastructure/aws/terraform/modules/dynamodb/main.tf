# ========================================
# DynamoDB Module - Secure AI Chat Proxy
# ========================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ========================================
# Local Variables
# ========================================

locals {
  table_name = var.table_name != "" ? var.table_name : "${var.name_prefix}-chat-sessions"
  
  common_tags = merge(var.tags, {
    Module = "DynamoDB"
    Name   = local.table_name
  })
}

# ========================================
# KMS Key for DynamoDB Encryption
# ========================================

resource "aws_kms_key" "dynamodb" {
  count = var.enable_custom_kms_key ? 1 : 0
  
  description             = "KMS key for DynamoDB table encryption - ${local.table_name}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true
  
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-dynamodb-kms-key"
  })
}

resource "aws_kms_alias" "dynamodb" {
  count = var.enable_custom_kms_key ? 1 : 0
  
  name          = "alias/${var.name_prefix}-dynamodb"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

# ========================================
# DynamoDB Table
# ========================================

resource "aws_dynamodb_table" "chat_sessions" {
  name           = local.table_name
  billing_mode   = var.billing_mode
  hash_key       = "sessionId"
  range_key      = "timestamp"
  
  # Capacity configuration (only for PROVISIONED billing mode)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  
  # Attributes
  attribute {
    name = "sessionId"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  attribute {
    name = "role"
    type = "S"
  }
  
  attribute {
    name = "userId"
    type = "S"
  }
  
  # TTL Configuration
  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }
  
  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_id  = var.enable_custom_kms_key ? aws_kms_key.dynamodb[0].arn : null
  }
  
  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }
  
  # Global Secondary Indexes
  global_secondary_index {
    name     = "UserRoleIndex"
    hash_key = "userId"
    range_key = "role"
    
    projection_type = "ALL"
    
    read_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }
  
  global_secondary_index {
    name     = "RoleTimestampIndex"
    hash_key = "role"
    range_key = "timestamp"
    
    projection_type = "ALL"
    
    read_capacity  = var.billing_mode == "PROVISIONED" ? var.gsi_read_capacity : null
    write_capacity = var.billing_mode == "PROVISIONED" ? var.gsi_write_capacity : null
  }
  
  # Stream configuration
  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? var.stream_view_type : null
  
  tags = local.common_tags
  
  lifecycle {
    prevent_destroy = true
  }
}

# ========================================
# Auto Scaling (for PROVISIONED billing mode)
# ========================================

resource "aws_appautoscaling_target" "read" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0
  
  max_capacity       = var.autoscaling_read_max
  min_capacity       = var.autoscaling_read_min
  resource_id        = "table/${aws_dynamodb_table.chat_sessions.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "read" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0
  
  name               = "${local.table_name}-read-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read[0].service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.autoscaling_read_target
  }
}

resource "aws_appautoscaling_target" "write" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0
  
  max_capacity       = var.autoscaling_write_max
  min_capacity       = var.autoscaling_write_min
  resource_id        = "table/${aws_dynamodb_table.chat_sessions.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "write" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0
  
  name               = "${local.table_name}-write-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write[0].service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.autoscaling_write_target
  }
}

# ========================================
# DynamoDB Contributor Insights (Optional)
# ========================================

resource "aws_dynamodb_contributor_insights" "chat_sessions" {
  count = var.enable_contributor_insights ? 1 : 0
  
  table_name = aws_dynamodb_table.chat_sessions.name
}

# ========================================
# DynamoDB Table Replica (for Global Tables)
# ========================================

resource "aws_dynamodb_table_replica" "chat_sessions" {
  count = length(var.replica_regions)
  
  global_table_arn = aws_dynamodb_table.chat_sessions.arn
  
  tags = local.common_tags
  
  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }
}

# ========================================
# CloudWatch Alarms
# ========================================

resource "aws_cloudwatch_metric_alarm" "read_throttle" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.table_name}-read-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottleCount"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.read_throttle_threshold
  alarm_description   = "This metric monitors DynamoDB read throttling"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    TableName = aws_dynamodb_table.chat_sessions.name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "write_throttle" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.table_name}-write-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottleCount"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.write_throttle_threshold
  alarm_description   = "This metric monitors DynamoDB write throttling"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    TableName = aws_dynamodb_table.chat_sessions.name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "consumed_read_capacity" {
  count = var.enable_cloudwatch_alarms && var.billing_mode == "PROVISIONED" ? 1 : 0
  
  alarm_name          = "${local.table_name}-high-read-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.read_capacity * 240  # 80% of 5-minute capacity
  alarm_description   = "This metric monitors DynamoDB consumed read capacity"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    TableName = aws_dynamodb_table.chat_sessions.name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "consumed_write_capacity" {
  count = var.enable_cloudwatch_alarms && var.billing_mode == "PROVISIONED" ? 1 : 0
  
  alarm_name          = "${local.table_name}-high-write-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedWriteCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.write_capacity * 240  # 80% of 5-minute capacity
  alarm_description   = "This metric monitors DynamoDB consumed write capacity"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    TableName = aws_dynamodb_table.chat_sessions.name
  }
  
  tags = local.common_tags
}