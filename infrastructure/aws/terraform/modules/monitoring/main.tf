# ========================================
# Monitoring Module - Secure AI Chat Proxy
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
# Data Sources
# ========================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ========================================
# Local Variables
# ========================================

locals {
  sns_topic_name = var.sns_topic_name != "" ? var.sns_topic_name : "${var.name_prefix}-alerts"
  
  common_tags = merge(var.tags, {
    Module = "Monitoring"
    Name   = "${var.name_prefix}-monitoring"
  })
  
  # Alarm actions (SNS topic ARN)
  alarm_actions = [aws_sns_topic.alerts.arn]
  
  # Dashboard name
  dashboard_name = "${var.name_prefix}-dashboard"
}

# ========================================
# SNS Topic for Alerts
# ========================================

resource "aws_sns_topic" "alerts" {
  name              = local.sns_topic_name
  display_name      = "Secure Chat Alerts"
  kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : "alias/aws/sns"
  
  delivery_policy = jsonencode({
    "http" = {
      "defaultHealthyRetryPolicy" = {
        "minDelayTarget"     = 20
        "maxDelayTarget"     = 20
        "numRetries"         = 3
        "numMaxDelayRetries" = 0
        "numMinDelayRetries" = 0
        "numNoDelayRetries"  = 0
        "backoffFunction"    = "linear"
      }
      "disableSubscriptionOverrides" = false
    }
  })
  
  tags = local.common_tags
}

# ========================================
# SNS Topic Subscriptions
# ========================================

# Email subscriptions
resource "aws_sns_topic_subscription" "email" {
  count = length(var.alert_email_endpoints)
  
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_endpoints[count.index]
  
  filter_policy = jsonencode({
    severity = ["HIGH", "CRITICAL"]
  })
}

# Slack webhook subscription
resource "aws_sns_topic_subscription" "slack" {
  count = var.slack_webhook_url != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
  
  filter_policy = jsonencode({
    severity = ["MEDIUM", "HIGH", "CRITICAL"]
  })
}

# ========================================
# Lambda Function Alarms
# ========================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.lambda_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_description   = "Lambda function error rate is too high"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "breaching"
  
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.lambda_function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.lambda_duration_threshold
  alarm_description   = "Lambda function duration is too high"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.lambda_function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Lambda function is being throttled"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  count = var.lambda_reserved_concurrency > 0 ? 1 : 0
  
  alarm_name          = "${var.lambda_function_name}-concurrent-executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Maximum"
  threshold           = var.lambda_reserved_concurrency * 0.8
  alarm_description   = "Lambda concurrent executions approaching reserved limit"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  
  tags = local.common_tags
}

# ========================================
# API Gateway Alarms
# ========================================

resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${var.api_gateway_name}-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.api_4xx_error_threshold
  alarm_description   = "API Gateway 4xx error rate is too high"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName   = var.api_gateway_name
    Stage     = var.api_gateway_stage
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.api_gateway_name}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.api_5xx_error_threshold
  alarm_description   = "API Gateway 5xx error rate is too high"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName   = var.api_gateway_name
    Stage     = var.api_gateway_stage
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.api_gateway_name}-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.api_latency_threshold
  alarm_description   = "API Gateway latency is too high"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName   = var.api_gateway_name
    Stage     = var.api_gateway_stage
  }
  
  tags = local.common_tags
}

# ========================================
# DynamoDB Alarms
# ========================================

resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  alarm_name          = "${var.dynamodb_table_name}-read-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ReadThrottleCount"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.dynamodb_read_throttle_threshold
  alarm_description   = "DynamoDB read operations are being throttled"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    TableName = var.dynamodb_table_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttles" {
  alarm_name          = "${var.dynamodb_table_name}-write-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "WriteThrottleCount"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.dynamodb_write_throttle_threshold
  alarm_description   = "DynamoDB write operations are being throttled"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    TableName = var.dynamodb_table_name
  }
  
  tags = local.common_tags
}

# ========================================
# Custom Application Metrics Alarms
# ========================================

resource "aws_cloudwatch_metric_alarm" "totp_validation_failures" {
  alarm_name          = "${var.lambda_function_name}-totp-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "${var.lambda_function_name}-TOTPFailures"
  namespace           = "Lambda/CustomMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.totp_failure_threshold
  alarm_description   = "High number of TOTP validation failures detected"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "anthropic_api_errors" {
  alarm_name          = "${var.lambda_function_name}-anthropic-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "${var.lambda_function_name}-AnthropicAPIErrors"
  namespace           = "Lambda/CustomMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.anthropic_api_error_threshold
  alarm_description   = "Anthropic API errors detected"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  
  tags = local.common_tags
}

# ========================================
# CloudWatch Dashboard
# ========================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name
  
  dashboard_body = jsonencode({
    widgets = [
      # Lambda metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            [".", "Throttles", ".", "."],
            [".", "ConcurrentExecutions", ".", "."]
          ]
          view     = "timeSeries"
          stacked  = false
          region   = data.aws_region.current.name
          title    = "Lambda Function Metrics"
          period   = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      
      # API Gateway metrics
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name, "Stage", var.api_gateway_stage],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."],
            [".", "Latency", ".", ".", ".", "."]
          ]
          view     = "timeSeries"
          stacked  = false
          region   = data.aws_region.current.name
          title    = "API Gateway Metrics"
          period   = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      
      # DynamoDB metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name],
            [".", "ConsumedWriteCapacityUnits", ".", "."],
            [".", "ReadThrottleCount", ".", "."],
            [".", "WriteThrottleCount", ".", "."]
          ]
          view     = "timeSeries"
          stacked  = false
          region   = data.aws_region.current.name
          title    = "DynamoDB Metrics"
          period   = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      
      # Custom application metrics
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["Lambda/CustomMetrics", "${var.lambda_function_name}-ErrorCount"],
            [".", "${var.lambda_function_name}-TOTPFailures"],
            [".", "${var.lambda_function_name}-AnthropicAPIErrors"]
          ]
          view     = "timeSeries"
          stacked  = false
          region   = data.aws_region.current.name
          title    = "Application Security Metrics"
          period   = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      
      # Recent logs widget
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        
        properties = {
          query   = "SOURCE '/aws/lambda/${var.lambda_function_name}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 50"
          region  = data.aws_region.current.name
          title   = "Recent Errors"
          view    = "table"
        }
      },
      
      # Performance overview
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { "stat": "Average" }],
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_gateway_name, "Stage", var.api_gateway_stage, { "stat": "Average" }],
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", var.lambda_function_name, { "stat": "Maximum" }]
          ]
          view     = "timeSeries"
          stacked  = false
          region   = data.aws_region.current.name
          title    = "Performance Overview"
          period   = 300
          annotations = {
            horizontal = [
              {
                label = "Lambda Timeout"
                value = var.lambda_duration_threshold
              }
            ]
          }
        }
      }
    ]
  })
}

# ========================================
# Composite Alarms
# ========================================

resource "aws_cloudwatch_composite_alarm" "service_health" {
  alarm_name        = "${var.name_prefix}-service-health"
  alarm_description = "Overall service health composite alarm"
  alarm_actions     = local.alarm_actions
  ok_actions        = local.alarm_actions
  
  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.lambda_errors.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.api_5xx_errors.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.dynamodb_read_throttles.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.dynamodb_write_throttles.alarm_name})"
  ])
  
  tags = local.common_tags
}

# ========================================
# Log Insights Queries
# ========================================

resource "aws_cloudwatch_query_definition" "error_analysis" {
  name = "${var.name_prefix}-error-analysis"
  
  log_group_names = [
    "/aws/lambda/${var.lambda_function_name}",
    "/aws/apigateway/${var.api_gateway_name}"
  ]
  
  query_string = <<-EOQ
    fields @timestamp, @message, @requestId
    | filter @message like /ERROR/
    | stats count() by bin(5m)
    | sort @timestamp desc
  EOQ
}

resource "aws_cloudwatch_query_definition" "totp_failures" {
  name = "${var.name_prefix}-totp-failures"
  
  log_group_names = [
    "/aws/lambda/${var.lambda_function_name}"
  ]
  
  query_string = <<-EOQ
    fields @timestamp, @message, @requestId
    | filter @message like /TOTP validation failed/
    | stats count() by bin(5m)
    | sort @timestamp desc
  EOQ
}

resource "aws_cloudwatch_query_definition" "performance_analysis" {
  name = "${var.name_prefix}-performance-analysis"
  
  log_group_names = [
    "/aws/lambda/${var.lambda_function_name}"
  ]
  
  query_string = <<-EOQ
    fields @timestamp, @duration, @billedDuration, @memorySize, @maxMemoryUsed
    | filter @type = "REPORT"
    | stats avg(@duration), max(@duration), min(@duration) by bin(5m)
    | sort @timestamp desc
  EOQ
}