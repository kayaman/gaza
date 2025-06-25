# ========================================
# Monitoring Module Outputs
# ========================================

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

output "sns_topic_id" {
  description = "ID of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.id
}

# ========================================
# Dashboard Outputs
# ========================================

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL to access the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

# ========================================
# Alarm Outputs
# ========================================

output "lambda_alarms" {
  description = "Lambda function alarms"
  value = {
    errors = {
      name = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_errors.arn
    }
    duration = {
      name = aws_cloudwatch_metric_alarm.lambda_duration.alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_duration.arn
    }
    throttles = {
      name = aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_throttles.arn
    }
    concurrent_executions = var.lambda_reserved_concurrency > 0 ? {
      name = aws_cloudwatch_metric_alarm.lambda_concurrent_executions[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_concurrent_executions[0].arn
    } : null
  }
}

output "api_gateway_alarms" {
  description = "API Gateway alarms"
  value = {
    errors_4xx = {
      name = aws_cloudwatch_metric_alarm.api_4xx_errors.alarm_name
      arn  = aws_cloudwatch_metric_alarm.api_4xx_errors.arn
    }
    errors_5xx = {
      name = aws_cloudwatch_metric_alarm.api_5xx_errors.alarm_name
      arn  = aws_cloudwatch_metric_alarm.api_5xx_errors.arn
    }
    latency = {
      name = aws_cloudwatch_metric_alarm.api_latency.alarm_name
      arn  = aws_cloudwatch_metric_alarm.api_latency.arn
    }
  }
}

output "dynamodb_alarms" {
  description = "DynamoDB alarms"
  value = {
    read_throttles = {
      name = aws_cloudwatch_metric_alarm.dynamodb_read_throttles.alarm_name
      arn  = aws_cloudwatch_metric_alarm.dynamodb_read_throttles.arn
    }
    write_throttles = {
      name = aws_cloudwatch_metric_alarm.dynamodb_write_throttles.alarm_name
      arn  = aws_cloudwatch_metric_alarm.dynamodb_write_throttles.arn
    }
  }
}

output "application_alarms" {
  description = "Custom application alarms"
  value = {
    totp_failures = {
      name = aws_cloudwatch_metric_alarm.totp_validation_failures.alarm_name
      arn  = aws_cloudwatch_metric_alarm.totp_validation_failures.arn
    }
    anthropic_errors = {
      name = aws_cloudwatch_metric_alarm.anthropic_api_errors.alarm_name
      arn  = aws_cloudwatch_metric_alarm.anthropic_api_errors.arn
    }
  }
}

output "composite_alarms" {
  description = "Composite alarms"
  value = {
    service_health = {
      name = aws_cloudwatch_composite_alarm.service_health.alarm_name
      arn  = aws_cloudwatch_composite_alarm.service_health.arn
    }
  }
}

# ========================================
# Log Insights Outputs
# ========================================

output "log_insights_queries" {
  description = "CloudWatch Log Insights query definitions"
  value = {
    error_analysis = {
      name = aws_cloudwatch_query_definition.error_analysis.name
      id   = aws_cloudwatch_query_definition.error_analysis.query_definition_id
    }
    totp_failures = {
      name = aws_cloudwatch_query_definition.totp_failures.name
      id   = aws_cloudwatch_query_definition.totp_failures.query_definition_id
    }
    performance_analysis = {
      name = aws_cloudwatch_query_definition.performance_analysis.name
      id   = aws_cloudwatch_query_definition.performance_analysis.query_definition_id
    }
  }
}

# ========================================
# Notification Configuration
# ========================================

output "notification_configuration" {
  description = "Notification configuration details"
  value = {
    sns_topic_arn    = aws_sns_topic.alerts.arn
    email_endpoints  = var.alert_email_endpoints
    slack_configured = var.slack_webhook_url != ""
    subscription_count = length(var.alert_email_endpoints) + (var.slack_webhook_url != "" ? 1 : 0)
  }
  sensitive = true
}

# ========================================
# Monitoring URLs
# ========================================

output "monitoring_urls" {
  description = "URLs for accessing monitoring resources"
  value = {
    dashboard = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
    
    lambda_metrics = "https://console.aws.amazon.com/lambda/home?region=${data.aws_region.current.name}#/functions/${var.lambda_function_name}?tab=monitoring"
    
    api_gateway_metrics = "https://console.aws.amazon.com/apigateway/home?region=${data.aws_region.current.name}#/apis/${var.api_gateway_name}/stages/${var.api_gateway_stage}"
    
    dynamodb_metrics = "https://console.aws.amazon.com/dynamodb/home?region=${data.aws_region.current.name}#tables:selected=${var.dynamodb_table_name};tab=monitoring"
    
    cloudwatch_alarms = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#alarmsV2:alarms"
    
    log_insights = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#logsV2:logs-insights"
    
    sns_topic = "https://console.aws.amazon.com/sns/v3/home?region=${data.aws_region.current.name}#/topic/${aws_sns_topic.alerts.arn}"
  }
}

# ========================================
# Monitoring Configuration Summary
# ========================================

output "monitoring_configuration" {
  description = "Complete monitoring configuration summary"
  value = {
    dashboards_created = 1
    alarms_created = {
      lambda_alarms    = 3 + (var.lambda_reserved_concurrency > 0 ? 1 : 0)
      api_alarms       = 3
      dynamodb_alarms  = 2
      application_alarms = 2
      composite_alarms = 1
      total_alarms    = 11 + (var.lambda_reserved_concurrency > 0 ? 1 : 0)
    }
    
    notification_channels = {
      email_subscriptions = length(var.alert_email_endpoints)
      slack_webhook      = var.slack_webhook_url != ""
      sns_topic_created  = true
    }
    
    log_insights_queries = 3
    
    monitoring_scope = {
      lambda_function  = var.lambda_function_name
      api_gateway     = "${var.api_gateway_name}:${var.api_gateway_stage}"
      dynamodb_table  = var.dynamodb_table_name
    }
    
    thresholds = {
      lambda_errors          = var.lambda_error_threshold
      lambda_duration_ms     = var.lambda_duration_threshold
      api_4xx_errors        = var.api_4xx_error_threshold
      api_5xx_errors        = var.api_5xx_error_threshold
      api_latency_ms        = var.api_latency_threshold
      dynamodb_read_throttles = var.dynamodb_read_throttle_threshold
      dynamodb_write_throttles = var.dynamodb_write_throttle_threshold
      totp_failures         = var.totp_failure_threshold
      anthropic_api_errors  = var.anthropic_api_error_threshold
    }
  }
}

# ========================================
# Cost Information
# ========================================

output "estimated_monthly_costs" {
  description = "Estimated monthly costs for monitoring resources"
  value = {
    cloudwatch_alarms = {
      count = 11 + (var.lambda_reserved_concurrency > 0 ? 1 : 0)
      cost_per_alarm = "$0.10"
      total_estimated = "$${(11 + (var.lambda_reserved_concurrency > 0 ? 1 : 0)) * 0.10}"
    }
    
    cloudwatch_dashboard = {
      cost_per_dashboard = "$3.00"
      total_estimated = "$3.00"
    }
    
    sns_topic = {
      cost_per_notification = "$0.50 per 1M notifications"
      estimated_monthly = "~$0.01 for typical usage"
    }
    
    log_insights = {
      cost_per_gb_scanned = "$0.005"
      estimated_monthly = "~$0.10-1.00 depending on usage"
    }
    
    total_estimated_range = "$3.11 - $4.11 per month"
    
    cost_optimization_notes = [
      "Alarm costs are fixed regardless of trigger frequency",
      "Dashboard costs are per dashboard, not per widget",
      "Log Insights costs scale with data scanned",
      "SNS costs scale with notification volume"
    ]
  }
}

# ========================================
# Health Check Information
# ========================================

output "health_check_endpoints" {
  description = "Health check and monitoring endpoints"
  value = {
    service_health_alarm = aws_cloudwatch_composite_alarm.service_health.arn
    
    individual_health_checks = {
      lambda_health    = aws_cloudwatch_metric_alarm.lambda_errors.arn
      api_health      = aws_cloudwatch_metric_alarm.api_5xx_errors.arn
      database_health = aws_cloudwatch_metric_alarm.dynamodb_write_throttles.arn
    }
    
    security_health_checks = {
      totp_security   = aws_cloudwatch_metric_alarm.totp_validation_failures.arn
      api_security    = aws_cloudwatch_metric_alarm.anthropic_api_errors.arn
    }
    
    performance_checks = {
      lambda_performance = aws_cloudwatch_metric_alarm.lambda_duration.arn
      api_performance   = aws_cloudwatch_metric_alarm.api_latency.arn
    }
  }
}