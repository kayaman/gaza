# ========================================
# Main Terraform Configuration
# Secure AI Chat Proxy Infrastructure
# ========================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  backend "s3" {
    bucket         = var.terraform_state_bucket
    key            = "secure-ai-chat-proxy/terraform.tfstate"
    region         = var.aws_region
    encrypt        = true
    dynamodb_table = var.terraform_lock_table
    
    # These will be provided via terraform init
    # terraform init -backend-config="bucket=your-terraform-state-bucket"
  }
}

# ========================================
# Provider Configuration
# ========================================

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "SecureAIChatProxy"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedBy   = var.created_by
      CostCenter  = var.cost_center
    }
  }
}

# ========================================
# Local Variables
# ========================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedBy   = var.created_by
  }

  # Security configuration
  totp_window_seconds = 30
  session_ttl_days    = var.session_ttl_days
  
  # Lambda configuration
  lambda_timeout     = 30
  lambda_memory_size = 256
  
  # DynamoDB configuration
  ttl_attribute = "ttl"
}

# ========================================
# Data Sources
# ========================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ========================================
# Random Resources for Security
# ========================================

resource "random_uuid" "deployment_id" {
  keepers = {
    environment = var.environment
    timestamp   = timestamp()
  }
}

resource "random_password" "api_key_salt" {
  length  = 32
  special = true
}

# ========================================
# Module Declarations
# ========================================

module "dynamodb" {
  source = "./modules/dynamodb"
  
  name_prefix = local.name_prefix
  
  table_name           = var.dynamodb_table_name
  ttl_attribute        = local.ttl_attribute
  point_in_time_recovery = var.enable_point_in_time_recovery
  
  tags = local.common_tags
}

module "lambda" {
  source = "./modules/lambda"
  
  name_prefix = local.name_prefix
  
  function_name    = var.lambda_function_name
  runtime          = var.lambda_runtime
  timeout          = local.lambda_timeout
  memory_size      = local.lambda_memory_size
  
  # Environment variables
  environment_variables = {
    ANTHROPIC_API_KEY    = var.anthropic_api_key
    TOTP_SECRET         = var.totp_secret
    DYNAMODB_TABLE      = module.dynamodb.table_name
    TOTP_WINDOW_SECONDS = local.totp_window_seconds
    SESSION_TTL_DAYS    = local.session_ttl_days
    ENVIRONMENT         = var.environment
    LOG_LEVEL          = var.log_level
  }
  
  # Permissions
  dynamodb_table_arn = module.dynamodb.table_arn
  
  tags = local.common_tags
  
  depends_on = [module.dynamodb]
}

module "api_gateway" {
  source = "./modules/api_gateway"
  
  name_prefix = local.name_prefix
  
  api_name        = var.api_gateway_name
  api_description = var.api_gateway_description
  stage_name      = var.api_gateway_stage
  
  # Lambda integration
  lambda_function_arn         = module.lambda.function_arn
  lambda_function_name        = module.lambda.function_name
  lambda_invoke_arn          = module.lambda.invoke_arn
  
  # Security settings
  throttle_rate_limit  = var.api_throttle_rate_limit
  throttle_burst_limit = var.api_throttle_burst_limit
  
  # Monitoring
  enable_access_logging = var.enable_api_access_logging
  log_retention_days   = var.cloudwatch_log_retention_days
  
  tags = local.common_tags
  
  depends_on = [module.lambda]
}

module "monitoring" {
  source = "./modules/monitoring"
  
  name_prefix = local.name_prefix
  
  # Resources to monitor
  lambda_function_name = module.lambda.function_name
  api_gateway_name     = module.api_gateway.api_name
  api_gateway_stage    = var.api_gateway_stage
  dynamodb_table_name  = module.dynamodb.table_name
  
  # Alerting configuration
  sns_topic_name           = var.sns_topic_name
  alert_email_endpoints    = var.alert_email_endpoints
  slack_webhook_url        = var.slack_webhook_url
  
  # Thresholds
  lambda_error_threshold     = var.lambda_error_threshold
  lambda_duration_threshold  = var.lambda_duration_threshold
  api_4xx_error_threshold   = var.api_4xx_error_threshold
  api_5xx_error_threshold   = var.api_5xx_error_threshold
  totp_failure_threshold    = var.totp_failure_threshold
  
  # Log retention
  log_retention_days = var.cloudwatch_log_retention_days
  
  tags = local.common_tags
  
  depends_on = [module.lambda, module.api_gateway, module.dynamodb]
}

# ========================================
# Security Resources
# ========================================

# CloudTrail for audit logging
resource "aws_cloudtrail" "secure_chat_trail" {
  count = var.enable_cloudtrail ? 1 : 0
  
  name           = "${local.name_prefix}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs[0].bucket
  
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.cloudtrail_logs[0].arn}/*"]
    }
    
    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = [module.dynamodb.table_arn]
    }
  }
  
  tags = local.common_tags
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket        = "${local.name_prefix}-cloudtrail-logs-${random_uuid.deployment_id.result}"
  force_destroy = var.environment != "production"
  
  tags = local.common_tags
}

resource "aws_s3_bucket_encryption" "cloudtrail_logs" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  count = var.enable_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================
# Backup and Disaster Recovery
# ========================================

# Lambda function for automated backups
module "backup" {
  count  = var.enable_automated_backups ? 1 : 0
  source = "./modules/backup"
  
  name_prefix = local.name_prefix
  
  dynamodb_table_arn  = module.dynamodb.table_arn
  backup_schedule     = var.backup_schedule
  backup_retention_days = var.backup_retention_days
  
  tags = local.common_tags
  
  depends_on = [module.dynamodb]
}