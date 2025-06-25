# ========================================
# Terraform State Management Bootstrap
# This file creates the S3 bucket and DynamoDB table
# required for Terraform remote state management
# ========================================

# This should be applied FIRST, before the main infrastructure
# Run this separately: terraform apply -target=module.terraform_state

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # NOTE: Comment out the backend configuration during bootstrap
  # Uncomment after bootstrap is complete
  /*
  backend "s3" {
    # These values will be provided via terraform init -backend-config
    # or via a backend.hcl file
  }
  */
}

# ========================================
# Bootstrap Resources
# ========================================

resource "random_string" "state_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  count = var.create_terraform_state_resources ? 1 : 0
  
  bucket = "${var.project_name}-terraform-state-${var.aws_region}-${random_string.state_bucket_suffix.result}"
  
  tags = {
    Name        = "Terraform State Bucket"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "TerraformState"
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    prevent_destroy = true
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  count = var.create_terraform_state_resources ? 1 : 0
  
  bucket = aws_s3_bucket.terraform_state[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = var.create_terraform_state_resources ? 1 : 0
  
  bucket = aws_s3_bucket.terraform_state[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = var.create_terraform_state_resources ? 1 : 0
  
  bucket = aws_s3_bucket.terraform_state[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count = var.create_terraform_state_resources ? 1 : 0
  
  bucket = aws_s3_bucket.terraform_state[0].id
  
  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"
    
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_lock" {
  count = var.create_terraform_state_resources ? 1 : 0
  
  name           = "${var.project_name}-terraform-lock-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  server_side_encryption {
    enabled = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = {
    Name        = "Terraform State Lock Table"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "TerraformStateLock"
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    prevent_destroy = true
  }
}

# ========================================
# Bootstrap Variables
# ========================================

variable "create_terraform_state_resources" {
  description = "Create S3 bucket and DynamoDB table for Terraform state"
  type        = bool
  default     = false
}

# ========================================
# Bootstrap Outputs
# ========================================

output "terraform_state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = var.create_terraform_state_resources ? aws_s3_bucket.terraform_state[0].id : null
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = var.create_terraform_state_resources ? aws_s3_bucket.terraform_state[0].arn : null
}

output "terraform_lock_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  value       = var.create_terraform_state_resources ? aws_dynamodb_table.terraform_lock[0].id : null
}

output "terraform_lock_table_arn" {
  description = "ARN of the DynamoDB table for Terraform state locking"
  value       = var.create_terraform_state_resources ? aws_dynamodb_table.terraform_lock[0].arn : null
}

output "backend_configuration" {
  description = "Backend configuration for terraform init"
  value = var.create_terraform_state_resources ? {
    bucket         = aws_s3_bucket.terraform_state[0].id
    key            = "secure-ai-chat-proxy/terraform.tfstate"
    region         = var.aws_region
    encrypt        = true
    dynamodb_table = aws_dynamodb_table.terraform_lock[0].id
    
    init_command = <<-EOT
      terraform init \
        -backend-config="bucket=${aws_s3_bucket.terraform_state[0].id}" \
        -backend-config="key=secure-ai-chat-proxy/terraform.tfstate" \
        -backend-config="region=${var.aws_region}" \
        -backend-config="encrypt=true" \
        -backend-config="dynamodb_table=${aws_dynamodb_table.terraform_lock[0].id}"
    EOT
  } : null
}

output "bootstrap_instructions" {
  description = "Instructions for completing the bootstrap process"
  value = var.create_terraform_state_resources ? {
    step_1 = "Bootstrap completed successfully!"
    step_2 = "Copy the S3 bucket name: ${aws_s3_bucket.terraform_state[0].id}"
    step_3 = "Copy the DynamoDB table name: ${aws_dynamodb_table.terraform_lock[0].id}"
    step_4 = "Update your terraform.tfvars file with these values"
    step_5 = "Uncomment the backend configuration in main.tf"
    step_6 = "Run the terraform init command shown in backend_configuration output"
    step_7 = "Run terraform plan and terraform apply for the main infrastructure"
    
    important_notes = [
      "The S3 bucket and DynamoDB table are protected from deletion",
      "Keep the bucket name and table name secure",
      "These resources will incur minimal costs",
      "The state bucket has versioning and encryption enabled"
    ]
  } : {
    note = "Set create_terraform_state_resources = true to create state management resources"
  }
}