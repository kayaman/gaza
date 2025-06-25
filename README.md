# Secure AI Chat Proxy

## Project Overview

A military-grade, enterprise-stealth communication system that enables secure AI conversations through corporate firewalls using TOTP-based encryption and traffic obfuscation. The solution provides undetectable access to AI services while maintaining bulletproof operational security.

## 📁 Project Structure

```
secure-ai-chat-proxy/
├── README.md                           # This file
├── LICENSE                             # MIT License
├── .gitignore                          # Git ignore patterns
├── .env.example                        # Environment variables template
│
├── docs/                               # Documentation
│   ├── ARCHITECTURE.md                 # Solution architecture overview
│   ├── SECURITY.md                     # Security analysis and OPSEC
│   ├── DEPLOYMENT.md                   # Deployment instructions
│   ├── API.md                          # API documentation
│   ├── TROUBLESHOOTING.md              # Common issues and solutions
│   └── diagrams/                       # Architecture diagrams
│       ├── solution-overview.png
│       ├── data-flow.png
│       ├── security-layers.png
│       └── deployment-topology.png
│
├── infrastructure/                     # Infrastructure as Code
│   ├── aws/                           # AWS resources
│   │   ├── cloudformation/            # CloudFormation templates
│   │   │   ├── lambda-function.yaml
│   │   │   ├── dynamodb-table.yaml
│   │   │   ├── api-gateway.yaml
│   │   │   └── iam-roles.yaml
│   │   ├── terraform/                 # Terraform configurations
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── modules/
│   │   │       ├── lambda/
│   │   │       ├── dynamodb/
│   │   │       └── api-gateway/
│   │   └── cdk/                       # AWS CDK (TypeScript)
│   │       ├── app.ts
│   │       ├── stacks/
│   │       └── constructs/
│   ├── vercel/                        # Vercel deployment
│   │   ├── vercel.json
│   │   └── api/
│   │       └── chat.ts
│   └── docker/                        # Docker configurations
│       ├── Dockerfile
│       ├── docker-compose.yml
│       └── nginx.conf
│
├── backend/                           # Backend services
│   ├── lambda/                        # AWS Lambda functions
│   │   ├── src/
│   │   │   ├── handlers/
│   │   │   │   ├── chat.js            # Main chat handler
│   │   │   │   ├── history.js         # History management
│   │   │   │   └── health.js          # Health check
│   │   │   ├── services/
│   │   │   │   ├── encryption.js      # Encryption/decryption
│   │   │   │   ├── totp.js            # TOTP validation
│   │   │   │   ├── anthropic.js       # Anthropic API client
│   │   │   │   └── storage.js         # DynamoDB operations
│   │   │   ├── utils/
│   │   │   │   ├── logger.js          # Logging utilities
│   │   │   │   ├── validator.js       # Input validation
│   │   │   │   └── errors.js          # Error handling
│   │   │   └── index.js               # Main Lambda entry point
│   │   ├── tests/                     # Unit tests
│   │   │   ├── handlers/
│   │   │   ├── services/
│   │   │   └── integration/
│   │   ├── package.json
│   │   ├── package-lock.json
│   │   └── webpack.config.js
│   ├── vercel/                        # Vercel serverless functions
│   │   ├── api/
│   │   │   └── chat.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── shared/                        # Shared utilities
│       ├── crypto/
│       ├── constants/
│       └── types/
│
├── client/                            # Client-side implementations
│   ├── postman/                       # Postman collections
│   │   ├── collections/
│   │   │   ├── secure-chat.postman_collection.json
│   │   │   ├── development.postman_collection.json
│   │   │   └── production.postman_collection.json
│   │   ├── environments/
│   │   │   ├── development.postman_environment.json
│   │   │   ├── staging.postman_environment.json
│   │   │   └── production.postman_environment.json
│   │   ├── scripts/
│   │   │   ├── encryption.js          # Client-side encryption
│   │   │   ├── totp-generator.js      # TOTP generation
│   │   │   └── traffic-obfuscation.js # Traffic mixing
│   │   └── README.md                  # Postman setup guide
│   ├── web/                           # Web client (optional)
│   │   ├── public/
│   │   ├── src/
│   │   │   ├── components/
│   │   │   ├── services/
│   │   │   └── utils/
│   │   ├── package.json
│   │   └── README.md
│   └── cli/                           # Command-line client
│       ├── src/
│       ├── bin/
│       ├── package.json
│       └── README.md
│
├── security/                          # Security configurations
│   ├── domains/                       # Domain management
│   │   ├── domain-registry.md         # Registered domains list
│   │   ├── dns-configurations/        # DNS setup files
│   │   └── ssl-certificates/          # SSL cert management
│   ├── totp/                         # TOTP management
│   │   ├── secret-generation.md       # TOTP secret setup
│   │   ├── backup-codes.md.example    # Backup procedures
│   │   └── rotation-schedule.md       # Key rotation schedule
│   ├── opsec/                        # Operational security
│   │   ├── traffic-patterns.md        # Traffic obfuscation
│   │   ├── emergency-procedures.md    # Burn notice protocols
│   │   └── detection-evasion.md       # Anti-detection measures
│   └── policies/                     # Security policies
│       ├── data-retention.md
│       ├── incident-response.md
│       └── compliance.md
│
├── monitoring/                        # Monitoring and observability
│   ├── cloudwatch/                   # AWS CloudWatch
│   │   ├── dashboards/
│   │   ├── alarms/
│   │   └── log-groups/
│   ├── scripts/                      # Monitoring scripts
│   │   ├── health-check.sh
│   │   ├── traffic-analysis.py
│   │   └── anomaly-detection.js
│   └── alerts/                       # Alert configurations
│       ├── slack-webhook.js
│       └── email-notifications.js
│
├── scripts/                          # Utility scripts
│   ├── deployment/                   # Deployment automation
│   │   ├── deploy-aws.sh
│   │   ├── deploy-vercel.sh
│   │   ├── setup-domains.sh
│   │   └── configure-ssl.sh
│   ├── maintenance/                  # Maintenance scripts
│   │   ├── cleanup-old-sessions.js
│   │   ├── rotate-domains.sh
│   │   ├── backup-data.js
│   │   └── security-audit.py
│   ├── testing/                      # Testing utilities
│   │   ├── load-test.js
│   │   ├── security-test.py
│   │   └── integration-test.sh
│   └── development/                  # Development tools
│       ├── local-setup.sh
│       ├── mock-anthropic.js
│       └── dev-server.js
│
├── config/                           # Configuration files
│   ├── aws/                         # AWS configurations
│   │   ├── lambda-config.json
│   │   ├── dynamodb-config.json
│   │   └── api-gateway-config.json
│   ├── security/                    # Security configurations
│   │   ├── encryption-settings.json
│   │   ├── totp-config.json
│   │   └── domain-rotation.json
│   └── environments/                # Environment-specific configs
│       ├── development.json
│       ├── staging.json
│       └── production.json
│
├── tests/                            # Test suites
│   ├── unit/                        # Unit tests
│   │   ├── encryption/
│   │   ├── totp/
│   │   └── api/
│   ├── integration/                 # Integration tests
│   │   ├── end-to-end/
│   │   ├── api-tests/
│   │   └── security-tests/
│   ├── performance/                 # Performance tests
│   │   ├── load-tests/
│   │   └── stress-tests/
│   └── security/                    # Security tests
│       ├── penetration-tests/
│       ├── vulnerability-scans/
│       └── compliance-tests/
│
└── tools/                            # Development tools
    ├── generators/                   # Code generators
    │   ├── domain-generator.js
    │   ├── totp-secret-generator.js
    │   └── session-id-generator.js
    ├── validators/                   # Validation tools
    │   ├── config-validator.js
    │   ├── security-checker.py
    │   └── domain-validator.sh
    └── utilities/                    # Miscellaneous utilities
        ├── log-parser.py
        ├── traffic-analyzer.js
        └── backup-manager.sh
```

## 🏗️ Solution Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Corporate      │    │  Public Cloud    │    │  AI Service     │
│  Network        │    │  Infrastructure  │    │  (Anthropic)    │
│                 │    │                  │    │                 │
│  ┌───────────┐  │    │  ┌─────────────┐ │    │  ┌───────────┐  │
│  │ Postman   │──┼────┼─▶│ AWS Lambda  │─┼────┼─▶│ Claude API│  │
│  │ Client    │  │    │  │ Proxy       │ │    │  │           │  │
│  └───────────┘  │    │  └─────────────┘ │    │  └───────────┘  │
│                 │    │         │        │    │                 │
│  ┌───────────┐  │    │  ┌─────────────┐ │    │                 │
│  │ TOTP      │  │    │  │ DynamoDB    │ │    │                 │
│  │ Generator │  │    │  │ Storage     │ │    │                 │
│  └───────────┘  │    │  └─────────────┘ │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Data Flow Diagram

```
1. User Input ──▶ 2. TOTP Generation ──▶ 3. Client Encryption
                                               │
8. User Sees Response ◀── 7. Client Decryption ◀── 6. Encrypted Response
                                               │
                                               ▼
                                        4. Encrypted Request
                                               │
                                               ▼
                            5. Lambda Processing:
                            ├─ TOTP Validation
                            ├─ Message Decryption
                            ├─ Anthropic API Call
                            ├─ Response Encryption
                            └─ DynamoDB Storage
```

### Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│                 TOTP-Based Encryption                       │
├─────────────────────────────────────────────────────────────┤
│                    TLS/HTTPS Transport                      │
├─────────────────────────────────────────────────────────────┤
│                  Domain Obfuscation                         │
├─────────────────────────────────────────────────────────────┤
│                  Traffic Randomization                      │
├─────────────────────────────────────────────────────────────┤
│               Corporate Network Evasion                     │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Tech Stack

### Backend Technologies

- **Runtime**: Node.js 18.x
- **Cloud Platform**: AWS (Lambda, API Gateway, DynamoDB)
- **Alternative**: Vercel (Serverless Functions)
- **Database**: DynamoDB (NoSQL, TTL-enabled)
- **API**: REST with JSON payloads

### Security Technologies

- **Encryption**: AES-256-GCM
- **Key Derivation**: PBKDF2-SHA256 (100,000 iterations)
- **Authentication**: TOTP (RFC 6238)
- **Transport**: TLS 1.3
- **Hash Algorithm**: HMAC-SHA1 (TOTP), SHA-256 (PBKDF2)

### Client Technologies

- **Primary Client**: Postman (JavaScript pre/post scripts)
- **Crypto API**: Web Crypto API (browser-based)
- **Alternative**: Node.js CLI client
- **Optional**: React Web client

### Infrastructure Technologies

- **IaC**: Terraform, CloudFormation, AWS CDK
- **DNS**: CloudFlare (proxy + obfuscation)
- **SSL**: Let's Encrypt certificates
- **Monitoring**: CloudWatch, custom scripts

### Protocols & Standards

- **HTTP/2 + TLS 1.3**: Transport protocol
- **RFC 6238**: TOTP specification
- **RFC 3394**: AES key wrapping
- **RFC 5869**: HKDF key derivation
- **NIST SP 800-38D**: GCM mode specification

## 🚀 Key Features

### Security Features

- **End-to-End Encryption**: AES-256-GCM with rotating keys
- **Perfect Forward Secrecy**: TOTP-based key rotation (30s intervals)
- **Anti-Replay Protection**: Time-limited TOTP validation
- **Traffic Obfuscation**: Business domain camouflage
- **Pattern Randomization**: Request timing and size variation
- **Emergency Procedures**: Instant burn/switch protocols

### Operational Features

- **Conversation History**: Encrypted storage with auto-expiry
- **Multi-Domain Support**: Automatic domain rotation
- **Load Balancing**: Multiple AWS regions support
- **Health Monitoring**: Automated endpoint health checks
- **Backup & Recovery**: Cross-region data replication

### Stealth Features

- **Business Domain Mimicry**: Legitimate-looking API endpoints
- **Traffic Mixing**: Interspersed legitimate API calls
- **Timing Obfuscation**: Business hours operation patterns
- **Payload Camouflage**: Business-like request structures
- **Plausible Deniability**: Cover story maintenance

## 📊 Data Structures

### DynamoDB Table Schema

```json
{
  "TableName": "encrypted-chat-sessions",
  "KeySchema": [
    { "AttributeName": "sessionId", "KeyType": "HASH" },
    { "AttributeName": "timestamp", "KeyType": "RANGE" }
  ],
  "AttributeDefinitions": [
    { "AttributeName": "sessionId", "AttributeType": "S" },
    { "AttributeName": "timestamp", "AttributeType": "S" }
  ],
  "TimeToLiveSpecification": {
    "AttributeName": "ttl",
    "Enabled": true
  }
}
```

### Message Structure

```json
{
  "sessionId": "proj-2025-k3n9x7m2q",
  "timestamp": "2025-06-23T14:30:00.000Z",
  "role": "user|assistant",
  "content": "ENCRYPTED:A1B2C3D4E5F6...:IV123456",
  "ttl": 1719504600
}
```

### API Request/Response Format

```json
{
  "action": "chat|getHistory",
  "sessionId": "string",
  "encryptedMessage": "hex_string",
  "iv": "hex_string",
  "totpCode": "6_digit_string"
}
```

```json
{
  "success": true,
  "encryptedResponse": "hex_string",
  "responseIv": "hex_string",
  "totpUsed": "6_digit_string",
  "sessionId": "string"
}
```

## 🛠️ Implementation Guide

### Prerequisites

- AWS Account with appropriate permissions
- Domain registrar access (for business domains)
- Google Authenticator app
- Postman application
- Node.js 18+ (for development)

### Quick Start

1. **Clone Repository**

   ```bash
   git clone https://github.com/your-org/secure-ai-chat-proxy.git
   cd secure-ai-chat-proxy
   ```

2. **Set Up Environment**

   ```bash
   cp .env.example .env
   # Edit .env with your configurations
   ```

3. **Deploy Infrastructure**

   ```bash
   cd scripts/deployment
   ./deploy-aws.sh
   ```

4. **Configure Domains**

   ```bash
   ./setup-domains.sh
   ```

5. **Set Up TOTP**

   ```bash
   cd tools/generators
   node totp-secret-generator.js
   ```

6. **Import Postman Collection**
   - Import `client/postman/collections/secure-chat.postman_collection.json`
   - Configure environment variables

### Detailed Implementation

Refer to individual documentation files:

- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Complete deployment guide
- [SECURITY.md](docs/SECURITY.md) - Security setup and OPSEC
- [API.md](docs/API.md) - API documentation and usage
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

## 🔐 Security Considerations

### Threat Model

- **Corporate Network Monitoring**: DLP, firewall, packet inspection
- **Traffic Analysis**: Pattern recognition, timing analysis
- **Domain Reputation**: Blacklist detection, security scanning
- **Payload Analysis**: Content inspection, size analysis

### Mitigation Strategies

- **Encryption**: Military-grade AES-256-GCM
- **Obfuscation**: Business domain camouflage
- **Randomization**: Traffic timing and size variation
- **Rotation**: Domain and key rotation schedules

### Compliance

- **GDPR**: Data minimization, encryption at rest
- **SOC 2**: Security controls, monitoring
- **ISO 27001**: Information security management

## 📈 Monitoring & Observability

### Metrics

- Request/response latency
- Error rates and types
- TOTP validation success/failure
- Domain health status
- Storage utilization

### Alerts

- Failed TOTP validations (potential attack)
- Unusual traffic patterns
- Domain blocking detection
- Service availability issues

### Logging

- Encrypted request metadata
- TOTP validation events
- Error conditions
- Performance metrics

## 🚨 Emergency Procedures

### Domain Burn Notice

1. Detect domain blocking/suspicion
2. Switch to backup domain immediately
3. Update DNS configurations
4. Clear client configurations
5. Monitor for continued access

### TOTP Compromise

1. Generate new TOTP secret
2. Update Lambda environment
3. Reconfigure client applications
4. Invalidate old sessions
5. Monitor for unauthorized access

### Data Breach Response

1. Assess compromise scope
2. Rotate all secrets immediately
3. Audit access logs
4. Notify stakeholders (if required)
5. Implement additional controls

## 📚 Additional Resources

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)
- [TOTP RFC 6238](https://tools.ietf.org/html/rfc6238)
- [AES-GCM Specification](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf)
- [Postman Documentation](https://learning.postman.com/)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

This is a security-focused project. Please follow responsible disclosure practices and maintain operational security when contributing.

## ⚠️ Disclaimer

This software is for educational and legitimate business purposes only. Users are responsible for compliance with their organization's policies and applicable laws. The authors assume no liability for misuse or policy violations.
