#!/bin/bash

# ========================================
# Secure AI Chat Proxy - Terraform Deployment Script
# ========================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT="development"
ACTION="plan"
AUTO_APPROVE=false
DESTROY=false
BOOTSTRAP=false
INIT_ONLY=false
SKIP_VALIDATION=false

# ========================================
# Helper Functions
# ========================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Secure AI Chat Proxy infrastructure with Terraform

OPTIONS:
    -e, --environment ENV     Environment to deploy (development|staging|production)
    -a, --action ACTION       Action to perform (plan|apply|destroy|output|validate)
    -y, --auto-approve        Auto-approve Terraform apply/destroy
    -d, --destroy             Destroy infrastructure
    -b, --bootstrap           Bootstrap Terraform state management
    -i, --init-only           Only run terraform init
    -s, --skip-validation     Skip Terraform validation
    -h, --help                Show this help message

EXAMPLES:
    # Bootstrap state management (run first)
    $0 --bootstrap --environment production

    # Plan deployment
    $0 --environment production --action plan

    # Apply deployment
    $0 --environment production --action apply --auto-approve

    # Destroy infrastructure
    $0 --environment production --destroy --auto-approve

    # Show outputs
    $0 --environment production --action output

EOF
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform 1.0 or later."
        exit 1
    fi
    
    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $TERRAFORM_VERSION"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    log_info "AWS Account: $AWS_ACCOUNT"
    log_info "AWS User: $AWS_USER"
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. Some features may not work properly."
    fi
}

validate_environment() {
    case $ENVIRONMENT in
        development|staging|production)
            log_info "Environment: $ENVIRONMENT"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            log_error "Valid environments: development, staging, production"
            exit 1
            ;;
    esac
}

check_files() {
    log_info "Checking required files..."
    
    # Check if environment file exists
    ENV_FILE="$TERRAFORM_DIR/environments/${ENVIRONMENT}.tfvars"
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file not found: $ENV_FILE"
        exit 1
    fi
    
    # Check if secrets file exists
    SECRETS_FILE="$TERRAFORM_DIR/secrets.tfvars"
    if [[ ! -f "$SECRETS_FILE" ]] && [[ "$BOOTSTRAP" != "true" ]]; then
        log_warning "Secrets file not found: $SECRETS_FILE"
        log_warning "Copy secrets.tfvars.template to secrets.tfvars and fill in your values"
        
        if [[ "$ACTION" == "apply" ]] || [[ "$ACTION" == "plan" ]]; then
            log_error "Secrets file is required for deployment"
            exit 1
        fi
    fi
    
    # Check if main.tf exists
    if [[ ! -f "$TERRAFORM_DIR/main.tf" ]]; then
        log_error "main.tf not found in $TERRAFORM_DIR"
        exit 1
    fi
}

bootstrap_state() {
    log_info "Bootstrapping Terraform state management..."
    
    cd "$TERRAFORM_DIR"
    
    # Comment out backend configuration for bootstrap
    if grep -q "backend \"s3\"" main.tf; then
        log_info "Commenting out backend configuration for bootstrap..."
        sed -i.backup 's/^  backend "s3"/  # backend "s3"/' main.tf
        sed -i.backup 's/^    bucket/    # bucket/' main.tf
        sed -i.backup 's/^    key/    # key/' main.tf
        sed -i.backup 's/^    region/    # region/' main.tf
        sed -i.backup 's/^    encrypt/    # encrypt/' main.tf
        sed -i.backup 's/^    dynamodb_table/    # dynamodb_table/' main.tf
    fi
    
    # Initialize Terraform
    terraform init
    
    # Create state management resources
    terraform apply \
        -var-file="environments/${ENVIRONMENT}.tfvars" \
        -var="create_terraform_state_resources=true" \
        -target=aws_s3_bucket.terraform_state \
        -target=aws_dynamodb_table.terraform_lock \
        -target=random_string.state_bucket_suffix \
        -auto-approve
    
    # Get the created bucket and table names
    STATE_BUCKET=$(terraform output -raw terraform_state_bucket_name)
    LOCK_TABLE=$(terraform output -raw terraform_lock_table_name)
    
    log_success "State management resources created:"
    log_success "  S3 Bucket: $STATE_BUCKET"
    log_success "  DynamoDB Table: $LOCK_TABLE"
    
    # Restore backend configuration
    if [[ -f main.tf.backup ]]; then
        log_info "Restoring backend configuration..."
        mv main.tf.backup main.tf
    fi
    
    # Create backend config file
    cat > backend.hcl << EOF
bucket         = "$STATE_BUCKET"
key            = "secure-ai-chat-proxy/terraform.tfstate"
region         = "$(grep aws_region "environments/${ENVIRONMENT}.tfvars" | cut -d'"' -f2)"
encrypt        = true
dynamodb_table = "$LOCK_TABLE"
EOF
    
    log_success "Backend configuration created: backend.hcl"
    log_info "Next steps:"
    log_info "  1. Update environments/${ENVIRONMENT}.tfvars with:"
    log_info "     terraform_state_bucket = \"$STATE_BUCKET\""
    log_info "     terraform_lock_table = \"$LOCK_TABLE\""
    log_info "  2. Run: terraform init -backend-config=backend.hcl"
    log_info "  3. Run: $0 --environment $ENVIRONMENT --action plan"
}

terraform_init() {
    log_info "Initializing Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if backend config exists
    if [[ -f "backend.hcl" ]] && [[ "$BOOTSTRAP" != "true" ]]; then
        terraform init -backend-config=backend.hcl
    else
        terraform init
    fi
}

terraform_validate() {
    if [[ "$SKIP_VALIDATION" == "false" ]]; then
        log_info "Validating Terraform configuration..."
        terraform validate
        log_success "Terraform configuration is valid"
    fi
}

terraform_plan() {
    log_info "Planning Terraform deployment..."
    
    local var_files=("-var-file=environments/${ENVIRONMENT}.tfvars")
    
    if [[ -f "secrets.tfvars" ]]; then
        var_files+=("-var-file=secrets.tfvars")
    fi
    
    if [[ "$DESTROY" == "true" ]]; then
        terraform plan -destroy "${var_files[@]}"
    else
        terraform plan "${var_files[@]}"
    fi
}

terraform_apply() {
    log_info "Applying Terraform configuration..."
    
    local var_files=("-var-file=environments/${ENVIRONMENT}.tfvars")
    local apply_args=()
    
    if [[ -f "secrets.tfvars" ]]; then
        var_files+=("-var-file=secrets.tfvars")
    fi
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        apply_args+=("-auto-approve")
    fi
    
    if [[ "$DESTROY" == "true" ]]; then
        terraform destroy "${var_files[@]}" "${apply_args[@]}"
    else
        terraform apply "${var_files[@]}" "${apply_args[@]}"
    fi
}

terraform_output() {
    log_info "Showing Terraform outputs..."
    terraform output
}

create_postman_config() {
    log_info "Creating Postman configuration..."
    
    if terraform output postman_configuration &> /dev/null; then
        terraform output -json postman_configuration > "postman-config-${ENVIRONMENT}.json"
        log_success "Postman configuration saved to: postman-config-${ENVIRONMENT}.json"
    else
        log_warning "No Postman configuration output available"
    fi
}

show_deployment_info() {
    log_info "Deployment completed successfully!"
    
    if terraform output deployment_info &> /dev/null; then
        echo
        log_info "Deployment Information:"
        terraform output deployment_info
    fi
    
    if terraform output api_gateway_invoke_url &> /dev/null; then
        echo
        API_URL=$(terraform output -raw api_gateway_invoke_url)
        log_success "API Gateway URL: $API_URL"
    fi
    
    echo
    log_info "Next steps:"
    log_info "  1. Configure Postman with the API Gateway URL"
    log_info "  2. Set up TOTP secret in Google Authenticator"
    log_info "  3. Test the deployment with a sample request"
    log_info "  4. Monitor CloudWatch logs for any issues"
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code $exit_code"
    fi
    exit $exit_code
}

# ========================================
# Main Script
# ========================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -a|--action)
                ACTION="$2"
                shift 2
                ;;
            -y|--auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            -d|--destroy)
                DESTROY=true
                shift
                ;;
            -b|--bootstrap)
                BOOTSTRAP=true
                shift
                ;;
            -i|--init-only)
                INIT_ONLY=true
                shift
                ;;
            -s|--skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Show script header
    echo -e "${BLUE}========================================"
    echo -e "Secure AI Chat Proxy - Terraform Deploy"
    echo -e "========================================${NC}"
    
    # Run checks
    check_prerequisites
    validate_environment
    
    if [[ "$BOOTSTRAP" == "true" ]]; then
        bootstrap_state
        exit 0
    fi
    
    check_files
    
    # Change to Terraform directory
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform_init
    
    if [[ "$INIT_ONLY" == "true" ]]; then
        log_success "Terraform initialization completed"
        exit 0
    fi
    
    # Validate configuration
    terraform_validate
    
    # Execute requested action
    case $ACTION in
        plan)
            terraform_plan
            ;;
        apply)
            terraform_apply
            create_postman_config
            show_deployment_info
            ;;
        destroy)
            DESTROY=true
            terraform_apply
            ;;
        output)
            terraform_output
            ;;
        validate)
            log_success "Terraform validation completed"
            ;;
        *)
            log_error "Invalid action: $ACTION"
            log_error "Valid actions: plan, apply, destroy, output, validate"
            exit 1
            ;;
    esac
    
    log_success "Action '$ACTION' completed successfully!"
}

# Run main function with all arguments
main "$@"