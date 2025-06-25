# ========================================
# API Gateway Module Outputs
# ========================================

output "api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_name" {
  description = "Name of the REST API"
  value       = aws_api_gateway_rest_api.main.name
}

output "api_root_resource_id" {
  description = "Resource ID of the REST API's root"
  value       = data.aws_api_gateway_resource.root.id
}

output "api_execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

# ========================================
# Deployment and Stage Outputs
# ========================================

output "deployment_id" {
  description = "ID of the deployment"
  value       = aws_api_gateway_deployment.main.id
}

output "deployment_invoke_url" {
  description = "URL to invoke the API"
  value       = aws_api_gateway_deployment.main.invoke_url
}

output "stage_name" {
  description = "Name of the stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "stage_arn" {
  description = "ARN of the stage"
  value       = aws_api_gateway_stage.main.arn
}

output "stage_invoke_url" {
  description = "URL to invoke the API pointing to the stage"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "invoke_url" {
  description = "URL to invoke the API (primary endpoint)"
  value       = aws_api_gateway_stage.main.invoke_url
  sensitive   = true
}

output "execution_arn" {
  description = "Execution ARN to be used in Lambda permissions"
  value       = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ========================================
# Resource Outputs
# ========================================

output "chat_resource_id" {
  description = "ID of the chat resource"
  value       = aws_api_gateway_resource.chat.id
}

output "health_resource_id" {
  description = "ID of the health resource"
  value       = aws_api_gateway_resource.health.id
}

# ========================================
# Custom Domain Outputs
# ========================================

output "domain_name" {
  description = "Custom domain name"
  value       = var.custom_domain_name != "" ? aws_api_gateway_domain_name.main[0].domain_name : null
}

output "domain_regional_domain_name" {
  description = "Regional domain name for the custom domain"
  value       = var.custom_domain_name != "" ? aws_api_gateway_domain_name.main[0].regional_domain_name : null
}

output "domain_regional_zone_id" {
  description = "Regional zone ID for the custom domain"
  value       = var.custom_domain_name != "" ? aws_api_gateway_domain_name.main[0].regional_zone_id : null
}

output "hosted_zone_id" {
  description = "Hosted zone ID for Route53 record"
  value       = var.custom_domain_name != "" ? aws_api_gateway_domain_name.main[0].regional_zone_id : null
}

output "custom_domain_url" {
  description = "URL for the custom domain"
  value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}${var.base_path != "" ? "/${var.base_path}" : ""}" : null
  sensitive   = true
}

# ========================================
# API Key and Usage Plan Outputs
# ========================================

output "api_key_id" {
  description = "ID of the API key"
  value       = var.create_api_key ? aws_api_gateway_api_key.main[0].id : null
}

output "api_key_value" {
  description = "Value of the API key"
  value       = var.create_api_key ? aws_api_gateway_api_key.main[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID of the usage plan"
  value       = var.create_usage_plan ? aws_api_gateway_usage_plan.main[0].id : null
}

output "usage_plan_arn" {
  description = "ARN of the usage plan"
  value       = var.create_usage_plan ? aws_api_gateway_usage_plan.main[0].arn : null
}

# ========================================
# Monitoring Outputs
# ========================================

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

# ========================================
# Security Outputs
# ========================================

output "waf_web_acl_association" {
  description = "WAF Web ACL association details"
  value = var.waf_web_acl_arn != "" ? {
    resource_arn = aws_wafv2_web_acl_association.main[0].resource_arn
    web_acl_arn  = aws_wafv2_web_acl_association.main[0].web_acl_arn
  } : null
}

# ========================================
# Configuration Summary
# ========================================

output "api_configuration" {
  description = "Complete API Gateway configuration"
  value = {
    api_name              = aws_api_gateway_rest_api.main.name
    api_id               = aws_api_gateway_rest_api.main.id
    stage_name           = aws_api_gateway_stage.main.stage_name
    endpoint_type        = var.endpoint_type
    invoke_url           = aws_api_gateway_stage.main.invoke_url
    custom_domain        = var.custom_domain_name
    throttle_rate_limit  = var.throttle_rate_limit
    throttle_burst_limit = var.throttle_burst_limit
    caching_enabled      = var.cache_cluster_enabled
    logging_enabled      = var.enable_access_logging
    xray_tracing_enabled = var.enable_xray_tracing
    api_key_required     = var.api_key_required
    cors_origins         = var.cors_origins
  }
  sensitive = true
}

# ========================================
# Endpoint Information
# ========================================

output "endpoints" {
  description = "API endpoints information"
  value = {
    base_url = aws_api_gateway_stage.main.invoke_url
    endpoints = {
      chat = {
        url    = "${aws_api_gateway_stage.main.invoke_url}/chat"
        method = "POST"
        description = "Main chat endpoint for encrypted conversations"
      }
      health = {
        url    = "${aws_api_gateway_stage.main.invoke_url}/health"
        method = "GET"
        description = "Health check endpoint"
      }
    }
    custom_domain_endpoints = var.custom_domain_name != "" ? {
      chat = {
        url    = "https://${var.custom_domain_name}${var.base_path != "" ? "/${var.base_path}" : ""}/chat"
        method = "POST"
        description = "Main chat endpoint via custom domain"
      }
      health = {
        url    = "https://${var.custom_domain_name}${var.base_path != "" ? "/${var.base_path}" : ""}/health"
        method = "GET"
        description = "Health check endpoint via custom domain"
      }
    } : null
  }
  sensitive = true
}

# ========================================
# Client Configuration
# ========================================

output "client_config" {
  description = "Configuration for API clients"
  value = {
    base_url = var.custom_domain_name != "" ? "https://${var.custom_domain_name}${var.base_path != "" ? "/${var.base_path}" : ""}" : aws_api_gateway_stage.main.invoke_url
    endpoints = {
      chat   = "/chat"
      health = "/health"
    }
    headers = merge(
      {
        "Content-Type" = "application/json"
      },
      var.api_key_required ? {
        "X-API-Key" = var.create_api_key ? aws_api_gateway_api_key.main[0].value : "REPLACE_WITH_API_KEY"
      } : {}
    )
    cors_enabled = length(var.cors_origins) > 0
    rate_limits = {
      requests_per_second = var.throttle_rate_limit
      burst_capacity     = var.throttle_burst_limit
    }
  }
  sensitive = true
}

# ========================================
# Deployment Information
# ========================================

output "deployment_info" {
  description = "Deployment information and recommendations"
  value = {
    api_gateway_console_url = "https://console.aws.amazon.com/apigateway/home?region=${data.aws_region.current.name}#/apis/${aws_api_gateway_rest_api.main.id}/stages/${var.stage_name}"
    cloudwatch_logs_url     = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.api_gateway.name, "/", "$252F")}"
    
    performance_recommendations = {
      caching = var.cache_cluster_enabled ? "Caching is enabled for improved performance" : "Consider enabling caching for frequently accessed endpoints"
      throttling = "Rate limiting configured: ${var.throttle_rate_limit} req/sec, burst: ${var.throttle_burst_limit}"
      custom_domain = var.custom_domain_name != "" ? "Custom domain configured for professional appearance" : "Consider setting up a custom domain"
    }
    
    security_recommendations = {
      cors = length(var.cors_origins) == 1 && var.cors_origins[0] == "*" ? "Consider restricting CORS origins for production" : "CORS origins are properly configured"
      api_key = var.api_key_required ? "API key authentication is enabled" : "Consider enabling API key authentication for additional security"
      waf = var.waf_web_acl_arn != "" ? "WAF protection is enabled" : "Consider enabling WAF for additional security"
      ssl = "TLS 1.2+ enforced for all connections"
    }
    
    monitoring_enabled = {
      access_logs      = var.enable_access_logging
      detailed_metrics = var.enable_detailed_metrics
      xray_tracing    = var.enable_xray_tracing
      data_trace      = var.enable_data_trace
    }
  }
}