# ========================================
# API Gateway Module - Secure AI Chat Proxy
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
  api_name = var.api_name != "" ? var.api_name : "${var.name_prefix}-api"
  
  common_tags = merge(var.tags, {
    Module = "APIGateway"
    Name   = local.api_name
  })
}

# ========================================
# CloudWatch Log Group for API Gateway
# ========================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null
  
  tags = local.common_tags
}

# ========================================
# API Gateway REST API
# ========================================

resource "aws_api_gateway_rest_api" "main" {
  name        = local.api_name
  description = var.api_description
  
  endpoint_configuration {
    types = [var.endpoint_type]
  }
  
  # API Key source
  api_key_source = var.api_key_source
  
  # Binary media types
  binary_media_types = var.binary_media_types
  
  # Minimum compression size
  minimum_compression_size = var.minimum_compression_size
  
  # Disable execute API endpoint if custom domain is used
  disable_execute_api_endpoint = var.custom_domain_name != "" ? var.disable_execute_api_endpoint : false
  
  tags = local.common_tags
}

# ========================================
# API Gateway Resources and Methods
# ========================================

# Root resource (/) already exists, get reference
data "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  path        = "/"
}

# Chat resource (/chat)
resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "chat"
}

# Health resource (/health)
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "health"
}

# ========================================
# CORS OPTIONS Methods
# ========================================

# OPTIONS method for /chat
resource "aws_api_gateway_method" "chat_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  
  type = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Max-Age"       = true
  }
  
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = aws_api_gateway_method_response.chat_options.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_origins)}'"
    "method.response.header.Access-Control-Max-Age"       = "'86400'"
  }
}

# ========================================
# POST Method for /chat
# ========================================

resource "aws_api_gateway_method" "chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "POST"
  authorization = var.authorization_type
  
  # API Key required if enabled
  api_key_required = var.api_key_required
  
  # Request validation
  request_validator_id = aws_api_gateway_request_validator.main.id
  
  # Request models
  request_models = {
    "application/json" = aws_api_gateway_model.chat_request.name
  }
}

resource "aws_api_gateway_integration" "chat_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.lambda_invoke_arn
  
  # Timeout configuration
  timeout_milliseconds = var.integration_timeout
}

resource "aws_api_gateway_method_response" "chat_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_post.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
  
  response_models = {
    "application/json" = aws_api_gateway_model.chat_response.name
  }
}

# ========================================
# GET Method for /health
# ========================================

resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.lambda_invoke_arn
}

resource "aws_api_gateway_method_response" "health_get_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }
}

# ========================================
# Request/Response Models
# ========================================

resource "aws_api_gateway_model" "chat_request" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "ChatRequest"
  content_type = "application/json"
  
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Chat Request Schema"
    type      = "object"
    properties = {
      action = {
        type = "string"
        enum = ["chat", "getHistory"]
      }
      sessionId = {
        type      = "string"
        minLength = 1
        maxLength = 128
      }
      encryptedMessage = {
        type = "string"
      }
      iv = {
        type = "string"
      }
      totpCode = {
        type    = "string"
        pattern = "^[0-9]{6}$"
      }
    }
    required = ["action", "sessionId", "totpCode"]
  })
}

resource "aws_api_gateway_model" "chat_response" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "ChatResponse"
  content_type = "application/json"
  
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Chat Response Schema"
    type      = "object"
    properties = {
      success = {
        type = "boolean"
      }
      encryptedResponse = {
        type = "string"
      }
      responseIv = {
        type = "string"
      }
      totpUsed = {
        type = "string"
      }
      sessionId = {
        type = "string"
      }
      error = {
        type = "string"
      }
    }
  })
}

# ========================================
# Request Validator
# ========================================

resource "aws_api_gateway_request_validator" "main" {
  name                        = "${local.api_name}-validator"
  rest_api_id                = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

# ========================================
# API Gateway Deployment
# ========================================

resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_method.chat_post,
    aws_api_gateway_method.chat_options,
    aws_api_gateway_method.health_get,
    aws_api_gateway_integration.chat_post,
    aws_api_gateway_integration.chat_options,
    aws_api_gateway_integration.health_get
  ]
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat.id,
      aws_api_gateway_resource.health.id,
      aws_api_gateway_method.chat_post.id,
      aws_api_gateway_method.chat_options.id,
      aws_api_gateway_method.health_get.id,
      aws_api_gateway_integration.chat_post.id,
      aws_api_gateway_integration.chat_options.id,
      aws_api_gateway_integration.health_get.id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# API Gateway Stage
# ========================================

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name
  
  # Access logging
  dynamic "access_log_settings" {
    for_each = var.enable_access_logging ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gateway.arn
      format = jsonencode({
        requestId      = "$requestId"
        ip            = "$sourceIp"
        user          = "$user"
        requestTime   = "$requestTime"
        httpMethod    = "$httpMethod"
        resourcePath  = "$resourcePath"
        status        = "$status"
        protocol      = "$protocol"
        responseLength = "$responseLength"
        responseTime  = "$responseTime"
        error         = "$error.message"
        integrationError = "$integration.error"
      })
    }
  }
  
  # Cache configuration
  dynamic "cache_cluster_enabled" {
    for_each = var.cache_cluster_enabled ? [1] : []
    content {
      cache_cluster_enabled = true
      cache_cluster_size    = var.cache_cluster_size
    }
  }
  
  # Tracing configuration
  tracing_enabled = var.enable_xray_tracing
  
  # Variables
  variables = var.stage_variables
  
  tags = local.common_tags
}

# ========================================
# Method Settings
# ========================================

resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"
  
  settings {
    # Metrics
    metrics_enabled = var.enable_detailed_metrics
    logging_level   = var.logging_level
    
    # Data trace
    data_trace_enabled = var.enable_data_trace
    
    # Throttling
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
    
    # Caching
    caching_enabled                = var.cache_cluster_enabled
    cache_ttl_in_seconds          = var.cache_ttl_seconds
    cache_data_encrypted          = true
    require_authorization_for_cache_control = true
    unauthorized_cache_control_header_strategy = "SUCCEED_WITH_RESPONSE_HEADER"
  }
}

# ========================================
# Custom Domain (Optional)
# ========================================

resource "aws_api_gateway_domain_name" "main" {
  count = var.custom_domain_name != "" ? 1 : 0
  
  domain_name              = var.custom_domain_name
  regional_certificate_arn = var.domain_certificate_arn
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  security_policy = "TLS_1_2"
  
  tags = local.common_tags
}

resource "aws_api_gateway_base_path_mapping" "main" {
  count = var.custom_domain_name != "" ? 1 : 0
  
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
  base_path   = var.base_path
}

# ========================================
# Route53 Record (Optional)
# ========================================

resource "aws_route53_record" "main" {
  count = var.custom_domain_name != "" && var.domain_hosted_zone_id != "" ? 1 : 0
  
  name    = aws_api_gateway_domain_name.main[0].domain_name
  type    = "A"
  zone_id = var.domain_hosted_zone_id
  
  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.main[0].regional_domain_name
    zone_id               = aws_api_gateway_domain_name.main[0].regional_zone_id
  }
}

# ========================================
# API Key and Usage Plan (Optional)
# ========================================

resource "aws_api_gateway_api_key" "main" {
  count = var.create_api_key ? 1 : 0
  
  name         = "${local.api_name}-key"
  description  = "API key for ${local.api_name}"
  enabled      = true
  
  tags = local.common_tags
}

resource "aws_api_gateway_usage_plan" "main" {
  count = var.create_usage_plan ? 1 : 0
  
  name         = "${local.api_name}-usage-plan"
  description  = "Usage plan for ${local.api_name}"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }
  
  quota_settings {
    limit  = var.usage_plan_quota_limit
    period = var.usage_plan_quota_period
  }
  
  throttle_settings {
    rate_limit  = var.usage_plan_rate_limit
    burst_limit = var.usage_plan_burst_limit
  }
  
  tags = local.common_tags
}

resource "aws_api_gateway_usage_plan_key" "main" {
  count = var.create_api_key && var.create_usage_plan ? 1 : 0
  
  key_id        = aws_api_gateway_api_key.main[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main[0].id
}

# ========================================
# WAF Web ACL Association (Optional)
# ========================================

resource "aws_wafv2_web_acl_association" "main" {
  count = var.waf_web_acl_arn != "" ? 1 : 0
  
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = var.waf_web_acl_arn
}