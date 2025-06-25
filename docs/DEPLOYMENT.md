# Complete Deployment Guide

## Pre-Deployment Checklist

### 1. Prerequisites

- [ ] AWS Account with Administrator access
- [ ] Domain registrar access (for business domains)
- [ ] Anthropic API key
- [ ] Google Authenticator app installed
- [ ] Postman application installed
- [ ] Node.js 18+ installed (for development/testing)
- [ ] Terraform installed (optional, for IaC)
- [ ] AWS CLI configured

### 2. Security Requirements

- [ ] Secure workstation for setup
- [ ] VPN connection (if required)
- [ ] Encrypted storage for secrets
- [ ] Backup procedures established
- [ ] Incident response plan reviewed

## Phase 1: Domain Registration & Configuration

### 1.1 Register Business Domains

```bash
# Register 4-5 legitimate business domains
# Examples (register through your preferred registrar):
api.consulting-metrics.com
webhook.project-sync.net
analytics.performance-data.org
sync.document-workflow.com
reporting.business-intelligence.net
```

### 1.2 Configure DNS with CloudFlare

```bash
# Add domains to CloudFlare
curl -X POST "https://api.cloudflare.com/client/v4/zones" \
     -H "X-Auth-Email: your-email@domain.com" \
     -H "X-Auth-Key: your-cloudflare-api-key" \
     -H "Content-Type: application/json" \
     --data '{
       "name": "api.consulting-metrics.com",
       "type": "full"
     }'

# Enable proxy (orange cloud)
curl -X PUT "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}" \
     -H "X-Auth-Email: your-email@domain.com" \
     -H "X-Auth-Key: your-cloudflare-api-key" \
     -H "Content-Type: application/json" \
     --data '{
       "type": "CNAME",
       "name": "api.consulting-metrics.com",
       "content": "your-lambda-url.execute-api.us-east-1.amazonaws.com",
       "proxied": true
     }'
```

### 1.3 SSL Certificate Setup

```bash
# Install certbot
sudo apt install certbot python3-certbot-dns-cloudflare

# Configure CloudFlare credentials
cat > ~/.secrets/cloudflare.ini << EOF
dns_cloudflare_email = your-email@domain.com
dns_cloudflare_api_key = your-cloudflare-api-key
EOF

# Generate SSL certificates
certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d api.consulting-metrics.com \
  -d webhook.project-sync.net \
  -d analytics.performance-data.org
```

## Phase 2: AWS Infrastructure Deployment

### 2.1 Environment Setup

```bash
# Clone the repository
git clone https://github.com/your-org/secure-ai-chat-proxy.git
cd secure-ai-chat-proxy

# Set up environment variables
cp .env.example .env

# Edit .env file
cat > .env << EOF
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# Anthropic API
ANTHROPIC_API_KEY=your-anthropic-api-key-here

# TOTP Configuration (generate using tools/generators/totp-secret-generator.js)
TOTP_SECRET=JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN

# Domain Configuration
PRIMARY_DOMAIN=api.consulting-metrics.com
BACKUP_DOMAINS=webhook.project-sync.net,analytics.performance-data.org

# Security Settings
SESSION_TTL_DAYS=30
MAX_MESSAGE_SIZE_KB=100
TOTP_WINDOW_SECONDS=30
EOF
```

### 2.2 Generate TOTP Secret

```bash
# Generate a secure TOTP secret
cd tools/generators
node totp-secret-generator.js

# Output example:
# Generated TOTP Secret: JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN
# QR Code URL: https://chart.googleapis.com/chart?chs=200x200&chld=M|0&cht=qr&chl=otpauth://totp/SecureChat?secret=JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN

# Add to Google Authenticator:
# 1. Open Google Authenticator
# 2. Tap "+" -> "Scan QR code"
# 3. Scan the generated QR code
# 4. Label: "Secure AI Chat"
```

### 2.3 Deploy with Terraform (Recommended)

```bash
# Initialize Terraform
cd infrastructure/terraform
terraform init

# Create terraform.tfvars
cat > terraform.tfvars << EOF
aws_region = "us-east-1"
environment = "production"
anthropic_api_key = "your-anthropic-api-key"
totp_secret = "JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN"
primary_domain = "api.consulting-metrics.com"
backup_domains = ["webhook.project-sync.net", "analytics.performance-data.org"]
session_ttl_days = 30
EOF

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Deploy infrastructure
terraform apply -var-file="terraform.tfvars"

# Save outputs
terraform output > ../outputs.txt
```

### 2.4 Manual AWS Deployment (Alternative)

```bash
# Create DynamoDB table
aws dynamodb create-table \
    --table-name encrypted-chat-sessions \
    --attribute-definitions \
        AttributeName=sessionId,AttributeType=S \
        AttributeName=timestamp,AttributeType=S \
    --key-schema \
        AttributeName=sessionId,KeyType=HASH \
        AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --time-to-live-specification \
        AttributeName=ttl,Enabled=true

# Create IAM role for Lambda
aws iam create-role \
    --role-name SecureChatLambdaRole \
    --assume-role-policy-document file://infrastructure/aws/iam-lambda-trust-policy.json

# Attach policies
aws iam attach-role-policy \
    --role-name SecureChatLambdaRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
    --role-name SecureChatLambdaRole \
    --policy-name DynamoDBAccess \
    --policy-document file://infrastructure/aws/iam-dynamodb-policy.json

# Package Lambda function
cd backend/lambda
zip -r function.zip src/ package.json

# Create Lambda function
aws lambda create-function \
    --function-name secure-chat-proxy \
    --runtime nodejs18.x \
    --role arn:aws:iam::123456789012:role/SecureChatLambdaRole \
    --handler src/index.handler \
    --zip-file fileb://function.zip \
    --timeout 30 \
    --memory-size 256 \
    --environment Variables='{
        "ANTHROPIC_API_KEY":"your-anthropic-api-key",
        "TOTP_SECRET":"JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN",
        "DYNAMODB_TABLE":"encrypted-chat-sessions"
    }'

# Create API Gateway
aws apigateway create-rest-api \
    --name secure-chat-api \
    --description "Secure AI Chat Proxy API"
```

## Phase 3: Postman Client Configuration

### 3.1 Import Collection

```bash
# Import the Postman collection
# File: client/postman/collections/secure-chat.postman_collection.json

# Import steps:
# 1. Open Postman
# 2. Click "Import" button
# 3. Select "Upload Files"
# 4. Choose the collection JSON file
# 5. Click "Import"
```

### 3.2 Configure Environment Variables

```javascript
// Set collection variables in Postman:
{
    "api_url": "https://api.consulting-metrics.com",
    "totp_secret": "JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN",
    "session_id": "{{$randomUUID}}",
    "current_totp": "",
    "message": "Hello, this is a test message",
    "backup_domains": [
        "https://webhook.project-sync.net",
        "https://analytics.performance-data.org"
    ]
}
```

### 3.3 Test Basic Functionality

```javascript
// Test TOTP generation
// Run this in Postman Console:
const totpSecret = pm.collectionVariables.get("totp_secret");
console.log("TOTP Secret configured:", !!totpSecret);

// Test encryption
pm.collectionVariables.set("message", "Test message from Postman");
// Run "Send Encrypted Message" request
// Check console for successful encryption/decryption
```

## Phase 4: Security Hardening

### 4.1 Lambda Security Configuration

```bash
# Enable VPC (optional, for additional security)
aws lambda update-function-configuration \
    --function-name secure-chat-proxy \
    --vpc-config SubnetIds=subnet-12345,SecurityGroupIds=sg-12345

# Enable dead letter queue
aws lambda update-function-configuration \
    --function-name secure-chat-proxy \
    --dead-letter-config TargetArn=arn:aws:sqs:us-east-1:123456789012:dlq-secure-chat

# Enable X-Ray tracing
aws lambda update-function-configuration \
    --function-name secure-chat-proxy \
    --tracing-config Mode=Active
```

### 4.2 DynamoDB Security

```bash
# Enable point-in-time recovery
aws dynamodb update-continuous-backups \
    --table-name encrypted-chat-sessions \
    --point-in-time-recovery-specification \
    PointInTimeRecoveryEnabled=true

# Enable encryption at rest
aws dynamodb update-table \
    --table-name encrypted-chat-sessions \
    --sse-specification Enabled=true,SSEType=KMS
```

### 4.3 API Gateway Security

```bash
# Enable CloudWatch logging
aws apigateway update-stage \
    --rest-api-id your-api-id \
    --stage-name prod \
    --patch-ops op=replace,path=/accessLogSettings/destinationArn,value=arn:aws:logs:us-east-1:123456789012:log-group:api-gateway-logs

# Enable throttling
aws apigateway update-stage \
    --rest-api-id your-api-id \
    --stage-name prod \
    --patch-ops op=replace,path=/throttle/rateLimit,value=1000 \
                op=replace,path=/throttle/burstLimit,value=2000
```

## Phase 5: Monitoring Setup

### 5.1 CloudWatch Configuration

```bash
# Create log groups
aws logs create-log-group \
    --log-group-name /aws/lambda/secure-chat-proxy

aws logs create-log-group \
    --log-group-name /aws/apigateway/secure-chat-api

# Create custom metrics
aws logs put-metric-filter \
    --log-group-name /aws/lambda/secure-chat-proxy \
    --filter-name TOTPValidationFailures \
    --filter-pattern "ERROR Invalid TOTP" \
    --metric-transformations \
        metricName=TOTPValidationFailures,metricNamespace=SecureChat,metricValue=1
```

### 5.2 CloudWatch Alarms

```bash
# TOTP validation failure alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "SecureChat-TOTPFailures" \
    --alarm-description "High TOTP validation failures" \
    --metric-name TOTPValidationFailures \
    --namespace SecureChat \
    --statistic Sum \
    --period 300 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1

# Lambda error rate alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "SecureChat-LambdaErrors" \
    --alarm-description "High Lambda error rate" \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --dimensions Name=FunctionName,Value=secure-chat-proxy \
    --statistic Sum \
    --period 300 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2
```

### 5.3 Custom Monitoring Scripts

```bash
# Deploy monitoring scripts
cd monitoring/scripts

# Health check script
chmod +x health-check.sh
./health-check.sh https://api.consulting-metrics.com

# Traffic analysis script
python3 traffic-analysis.py --domain api.consulting-metrics.com --hours 24

# Anomaly detection
node anomaly-detection.js --function secure-chat-proxy --threshold 95
```

## Phase 6: Testing & Validation

### 6.1 Unit Tests

```bash
# Run backend unit tests
cd backend/lambda
npm test

# Run integration tests
npm run test:integration

# Run security tests
npm run test:security
```

### 6.2 End-to-End Testing

```bash
# Test complete flow
cd tests/integration
node end-to-end-test.js

# Test with multiple domains
node domain-rotation-test.js

# Test TOTP expiration handling
node totp-timing-test.js
```

### 6.3 Load Testing

```bash
# Install artillery for load testing
npm install -g artillery

# Run load test
cd tests/performance
artillery run load-test.yaml

# Results analysis
artillery report load-test-results.json
```

## Phase 7: Production Deployment

### 7.1 DNS Cutover

```bash
# Update primary domain DNS
aws route53 change-resource-record-sets \
    --hosted-zone-id Z123456789 \
    --change-batch file://dns-changeset.json

# Verify DNS propagation
dig api.consulting-metrics.com
nslookup api.consulting-metrics.com 8.8.8.8
```

### 7.2 SSL Certificate Deployment

```bash
# Upload certificates to AWS Certificate Manager
aws acm import-certificate \
    --certificate fileb://api.consulting-metrics.com.crt \
    --private-key fileb://api.consulting-metrics.com.key \
    --certificate-chain fileb://intermediate.crt

# Associate with API Gateway
aws apigateway update-domain-name \
    --domain-name api.consulting-metrics.com \
    --patch-ops op=replace,path=/certificateArn,value=arn:aws:acm:us-east-1:123456789012:certificate/12345
```

### 7.3 Final Validation

```bash
# Test all endpoints
curl -X POST https://api.consulting-metrics.com/chat \
    -H "Content-Type: application/json" \
    -d '{"action":"health"}'

# Verify monitoring
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=secure-chat-proxy \
    --start-time 2025-06-23T12:00:00Z \
    --end-time 2025-06-23T13:00:00Z \
    --period 300 \
    --statistics Sum
```

## Phase 8: Operational Procedures

### 8.1 Daily Operations

```bash
# Morning health check
./scripts/daily-health-check.sh

# Monitor key metrics
aws cloudwatch get-dashboard --dashboard-name SecureChat-Operations

# Review logs for anomalies
aws logs filter-log-events \
    --log-group-name /aws/lambda/secure-chat-proxy \
    --start-time $(date -d '1 hour ago' +%s)000
```

### 8.2 Weekly Maintenance

```bash
# Rotate backup domains
./scripts/maintenance/rotate-domains.sh

# Clean up old sessions
node scripts/maintenance/cleanup-old-sessions.js

# Security audit
python3 scripts/maintenance/security-audit.py
```

### 8.3 Monthly Tasks

```bash
# TOTP secret rotation (if required)
./scripts/maintenance/rotate-totp-secret.sh

# Performance optimization review
./scripts/maintenance/performance-review.sh

# Cost optimization analysis
aws ce get-cost-and-usage \
    --time-period Start=2025-05-01,End=2025-06-01 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE
```

## Emergency Procedures

### Domain Burn Protocol

```bash
# Emergency domain switch
./scripts/emergency/burn-domain.sh api.consulting-metrics.com webhook.project-sync.net

# Update client configurations
./scripts/emergency/update-client-config.sh

# Verify new domain functionality
./scripts/emergency/validate-new-domain.sh webhook.project-sync.net
```

### Security Incident Response

```bash
# Immediate isolation
aws lambda update-function-configuration \
    --function-name secure-chat-proxy \
    --environment Variables='{}'

# Forensic data collection
./scripts/emergency/collect-forensics.sh

# Clean rebuild
./scripts/emergency/clean-rebuild.sh
```

## Post-Deployment Checklist

- [ ] All domains resolving correctly
- [ ] SSL certificates valid and trusted
- [ ] Lambda function executing without errors
- [ ] DynamoDB table accessible and storing data
- [ ] Postman client successfully encrypting/decrypting
- [ ] TOTP validation working correctly
- [ ] Monitoring and alerting active
- [ ] Backup procedures tested
- [ ] Emergency procedures documented
- [ ] Team training completed

## Troubleshooting Quick Reference

| Issue                   | Symptoms             | Solution                               |
| ----------------------- | -------------------- | -------------------------------------- |
| TOTP validation failure | 401 errors           | Check phone time sync, regenerate TOTP |
| Domain not resolving    | DNS errors           | Check CloudFlare DNS settings          |
| Lambda timeout          | 504 errors           | Increase timeout, optimize code        |
| DynamoDB throttling     | 400 errors           | Enable auto-scaling                    |
| SSL certificate issues  | Certificate warnings | Renew certificates, check expiration   |
| High costs              | Billing alerts       | Review Lambda memory, DynamoDB usage   |

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
