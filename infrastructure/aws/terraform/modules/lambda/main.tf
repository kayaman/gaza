# ========================================
# Lambda Module - Secure AI Chat Proxy
# ========================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
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
  function_name = var.function_name != "" ? var.function_name : "${var.name_prefix}-lambda"
  
  common_tags = merge(var.tags, {
    Module = "Lambda"
    Name   = local.function_name
  })
  
  # Source code path
  source_path = var.source_path != "" ? var.source_path : "${path.root}/../../../backend/lambda"
  
  # Environment variables with defaults
  environment_variables = merge({
    NODE_ENV     = "production"
    LOG_LEVEL    = "INFO"
    AWS_REGION   = data.aws_region.current.name
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
  }, var.environment_variables)
}

# ========================================
# Lambda Source Code Package
# ========================================

# Archive source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.source_path
  output_path = "${path.module}/lambda_function.zip"
  
  excludes = [
    "node_modules",
    "tests",
    "*.test.js",
    "*.spec.js",
    ".env*",
    "README.md",
    ".git*"
  ]
}

# ========================================
# IAM Role for Lambda
# ========================================

# Lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.function_name}-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy (if VPC is enabled)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count = var.vpc_config.subnet_ids != null ? 1 : 0
  
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing policy (if enabled)
resource "aws_iam_role_policy_attachment" "lambda_xray_execution" {
  count = var.enable_xray_tracing ? 1 : 0
  
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# DynamoDB access policy
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${local.function_name}-dynamodb-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      }
    ]
  })
}

# KMS access policy (if custom KMS key is used)
resource "aws_iam_role_policy" "lambda_kms_policy" {
  count = var.kms_key_arn != "" ? 1 : 0
  
  name = "${local.function_name}-kms-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Secrets Manager access policy (if enabled)
resource "aws_iam_role_policy" "lambda_secrets_policy" {
  count = var.enable_secrets_manager_access ? 1 : 0
  
  name = "${local.function_name}-secrets-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/*"
      }
    ]
  })
}

# ========================================
# Security Group for VPC Lambda
# ========================================

resource "aws_security_group" "lambda_sg" {
  count = var.vpc_config.subnet_ids != null ? 1 : 0
  
  name_prefix = "${local.function_name}-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_config.vpc_id
  
  # Outbound rules for HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }
  
  # Outbound rules for DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS outbound"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.function_name}-security-group"
  })
}

# ========================================
# CloudWatch Log Group
# ========================================

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null
  
  tags = local.common_tags
}

# ========================================
# Lambda Function
# ========================================

resource "aws_lambda_function" "main" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.function_name
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = var.handler
  runtime         = var.runtime
  timeout         = var.timeout
  memory_size     = var.memory_size
  architectures   = [var.architecture]
  
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  # Environment variables
  environment {
    variables = local.environment_variables
  }
  
  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config.subnet_ids != null ? [1] : []
    content {
      subnet_ids         = var.vpc_config.subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }
  
  # Dead letter queue configuration
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != "" ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }
  
  # X-Ray tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
  
  # File system configuration
  dynamic "file_system_config" {
    for_each = var.efs_config.access_point_arn != "" ? [1] : []
    content {
      arn              = var.efs_config.access_point_arn
      local_mount_path = var.efs_config.local_mount_path
    }
  }
  
  # Image configuration (for container images)
  dynamic "image_config" {
    for_each = var.package_type == "Image" ? [1] : []
    content {
      command           = var.image_config.command
      entry_point       = var.image_config.entry_point
      working_directory = var.image_config.working_directory
    }
  }
  
  # Ephemeral storage
  ephemeral_storage {
    size = var.ephemeral_storage_size
  }
  
  tags = local.common_tags
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# ========================================
# Lambda Function URL (if enabled)
# ========================================

resource "aws_lambda_function_url" "main" {
  count = var.enable_function_url ? 1 : 0
  
  function_name      = aws_lambda_function.main.function_name
  authorization_type = var.function_url_auth_type
  
  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age          = cors.value.max_age
    }
  }
}

# ========================================
# Lambda Concurrency Configuration
# ========================================

resource "aws_lambda_provisioned_concurrency_config" "main" {
  count = var.provisioned_concurrency > 0 ? 1 : 0
  
  function_name                     = aws_lambda_function.main.function_name
  provisioned_concurrent_executions = var.provisioned_concurrency
  qualifier                        = aws_lambda_alias.main[0].name
  
  depends_on = [aws_lambda_alias.main]
}

resource "aws_lambda_function_event_invoke_config" "main" {
  function_name = aws_lambda_function.main.function_name
  
  maximum_event_age       = var.maximum_event_age
  maximum_retry_attempts  = var.maximum_retry_attempts
  
  dynamic "destination_config" {
    for_each = var.async_config.on_success_arn != "" || var.async_config.on_failure_arn != "" ? [1] : []
    content {
      dynamic "on_failure" {
        for_each = var.async_config.on_failure_arn != "" ? [1] : []
        content {
          destination = var.async_config.on_failure_arn
        }
      }
      
      dynamic "on_success" {
        for_each = var.async_config.on_success_arn != "" ? [1] : []
        content {
          destination = var.async_config.on_success_arn
        }
      }
    }
  }
}

# ========================================
# Lambda Alias and Versioning
# ========================================

resource "aws_lambda_alias" "main" {
  count = var.create_alias ? 1 : 0
  
  name             = var.alias_name
  description      = "Alias for ${local.function_name}"
  function_name    = aws_lambda_function.main.function_name
  function_version = var.publish_version ? aws_lambda_function.main.version : "$LATEST"
  
  dynamic "routing_config" {
    for_each = var.alias_routing_config.additional_version_weights != null ? [1] : []
    content {
      additional_version_weights = var.alias_routing_config.additional_version_weights
    }
  }
}

# ========================================
# CloudWatch Alarms
# ========================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_alarm_threshold
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.duration_alarm_threshold
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.throttle_alarm_threshold
  alarm_description   = "This metric monitors lambda throttles"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  count = var.enable_cloudwatch_alarms && var.reserved_concurrency > 0 ? 1 : 0
  
  alarm_name          = "${local.function_name}-concurrent-executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Maximum"
  threshold           = var.reserved_concurrency * 0.8  # 80% of reserved concurrency
  alarm_description   = "This metric monitors lambda concurrent executions"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
  
  tags = local.common_tags
}

# ========================================
# Lambda Reserved Concurrency
# ========================================

resource "aws_lambda_function_concurrency" "main" {
  count = var.reserved_concurrency > 0 ? 1 : 0
  
  function_name                = aws_lambda_function.main.function_name
  reserved_concurrent_executions = var.reserved_concurrency
}

# ========================================
# Lambda Layer (if specified)
# ========================================

resource "aws_lambda_layer_version" "dependencies" {
  count = var.create_layer ? 1 : 0
  
  filename            = var.layer_filename
  layer_name          = "${local.function_name}-dependencies"
  compatible_runtimes = [var.runtime]
  compatible_architectures = [var.architecture]
  
  description = "Dependencies layer for ${local.function_name}"
  
  source_code_hash = var.layer_source_code_hash
}

# ========================================
# Lambda Event Source Mappings
# ========================================

resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  count = var.dynamodb_stream_arn != "" ? 1 : 0
  
  event_source_arn  = var.dynamodb_stream_arn
  function_name     = aws_lambda_function.main.arn
  starting_position = var.stream_starting_position
  batch_size        = var.stream_batch_size
  
  dynamic "filter_criteria" {
    for_each = var.stream_filter_criteria != null ? [var.stream_filter_criteria] : []
    content {
      dynamic "filter" {
        for_each = filter_criteria.value.filters
        content {
          pattern = filter.value.pattern
        }
      }
    }
  }
}

# ========================================
# Lambda Permission for API Gateway
# ========================================

resource "aws_lambda_permission" "api_gateway" {
  count = var.allow_api_gateway_invoke ? 1 : 0
  
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  qualifier     = var.create_alias ? aws_lambda_alias.main[0].name : null
  
  # More specific source ARN can be specified if needed
  source_arn = var.api_gateway_source_arn != "" ? var.api_gateway_source_arn : null
}

# ========================================
# Lambda Permission for CloudWatch Events
# ========================================

resource "aws_lambda_permission" "cloudwatch_events" {
  count = var.allow_cloudwatch_events_invoke ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  qualifier     = var.create_alias ? aws_lambda_alias.main[0].name : null
}

# ========================================
# Lambda Permission for S3
# ========================================

resource "aws_lambda_permission" "s3" {
  count = var.allow_s3_invoke ? 1 : 0
  
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "s3.amazonaws.com"
  qualifier     = var.create_alias ? aws_lambda_alias.main[0].name : null
  source_arn    = var.s3_bucket_arn
}

# ========================================
# Lambda Permission for SNS
# ========================================

resource "aws_lambda_permission" "sns" {
  count = var.allow_sns_invoke ? 1 : 0
  
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "sns.amazonaws.com"
  qualifier     = var.create_alias ? aws_lambda_alias.main[0].name : null
  source_arn    = var.sns_topic_arn
}

# ========================================
# Lambda Custom Metric Filters
# ========================================

resource "aws_cloudwatch_log_metric_filter" "error_count" {
  count = var.enable_custom_metrics ? 1 : 0
  
  name           = "${local.function_name}-error-count"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name
  pattern        = "ERROR"
  
  metric_transformation {
    name      = "${local.function_name}-ErrorCount"
    namespace = "Lambda/CustomMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "totp_validation_failures" {
  count = var.enable_custom_metrics ? 1 : 0
  
  name           = "${local.function_name}-totp-failures"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name
  pattern        = "TOTP validation failed"
  
  metric_transformation {
    name      = "${local.function_name}-TOTPFailures"
    namespace = "Lambda/CustomMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "anthropic_api_errors" {
  count = var.enable_custom_metrics ? 1 : 0
  
  name           = "${local.function_name}-anthropic-errors"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name
  pattern        = "Anthropic API error"
  
  metric_transformation {
    name      = "${local.function_name}-AnthropicAPIErrors"
    namespace = "Lambda/CustomMetrics"
    value     = "1"
  }
}

# ========================================
# CloudWatch Dashboard for Lambda
# ========================================

resource "aws_cloudwatch_dashboard" "lambda_dashboard" {
  count = var.create_dashboard ? 1 : 0
  
  dashboard_name = "${local.function_name}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.main.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            [".", "Throttles", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.lambda_logs.name}'\n| fields @timestamp, @message\n| sort @timestamp desc\n| limit 100"
          region  = data.aws_region.current.name
          title   = "Recent Logs"
        }
      }
    ]
  })
}

# ========================================
# Lambda Insights Extension (if enabled)
# ========================================

locals {
  # Lambda Insights extension ARN based on region and architecture
  insights_extension_arn = var.enable_lambda_insights ? (
    var.architecture == "arm64" ? 
    "arn:aws:lambda:${data.aws_region.current.name}:580247275435:layer:LambdaInsightsExtension-Arm64:5" :
    "arn:aws:lambda:${data.aws_region.current.name}:580247275435:layer:LambdaInsightsExtension:21"
  ) : null
  
  # Combine user layers with insights layer
  all_layers = var.enable_lambda_insights ? concat(var.layers, [local.insights_extension_arn]) : var.layers
}

# Update the Lambda function to include layers
resource "aws_lambda_function" "main" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.function_name
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = var.handler
  runtime         = var.runtime
  timeout         = var.timeout
  memory_size     = var.memory_size
  architectures   = [var.architecture]
  layers          = local.all_layers
  
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  # Environment variables
  environment {
    variables = local.environment_variables
  }
  
  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config.subnet_ids != null ? [1] : []
    content {
      subnet_ids         = var.vpc_config.subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }
  
  # Dead letter queue configuration
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != "" ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }
  
  # X-Ray tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
  
  # File system configuration
  dynamic "file_system_config" {
    for_each = var.efs_config.access_point_arn != "" ? [1] : []
    content {
      arn              = var.efs_config.access_point_arn
      local_mount_path = var.efs_config.local_mount_path
    }
  }
  
  # Image configuration (for container images)
  dynamic "image_config" {
    for_each = var.package_type == "Image" ? [1] : []
    content {
      command           = var.image_config.command
      entry_point       = var.image_config.entry_point
      working_directory = var.image_config.working_directory
    }
  }
  
  # Ephemeral storage
  ephemeral_storage {
    size = var.ephemeral_storage_size
  }
  
  tags = local.common_tags
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# Note: The above resource definition replaces the earlier incomplete one
# Remove the earlier incomplete aws_lambda_function.main resource block