# Architecture Overview

This document provides a comprehensive architectural overview of the Gaza Secure AI Chat Proxy system - a military-grade, enterprise-stealth communication system that enables secure AI conversations through corporate firewalls using TOTP-based encryption and traffic obfuscation.

## System Architecture Diagrams

### High-Level Solution Architecture

```mermaid
graph TB
    subgraph "Corporate Network"
        C[Client/Postman]
        T[TOTP Generator]
        E[Encryption Module]
    end

    subgraph "Internet/Firewall"
        F[Corporate Firewall]
        CF[CloudFlare Proxy]
    end

    subgraph "AWS Cloud Infrastructure"
        ALB[Application Load Balancer]
        AG[API Gateway]
        L[Lambda Function]
        DB[(DynamoDB)]
        CW[CloudWatch]
    end

    subgraph "External Services"
        A[Anthropic Claude API]
    end

    C --> T
    T --> E
    E --> F
    F --> CF
    CF --> ALB
    ALB --> AG
    AG --> L
    L --> DB
    L --> A
    L --> CW

    style C fill:#ff9999
    style L fill:#99ccff
    style DB fill:#99ff99
    style A fill:#ffcc99
```

### Detailed Data Flow Architecture

```mermaid
sequenceDiagram
    participant User as Corporate User
    participant TOTP as TOTP App
    participant Client as Postman Client
    participant CF as CloudFlare
    participant Lambda as AWS Lambda
    participant DDB as DynamoDB
    participant Claude as Anthropic API

    User->>TOTP: Generate current code
    TOTP-->>User: 6-digit code
    User->>Client: Input message + TOTP
    Client->>Client: Encrypt with TOTP-derived key
    Client->>CF: HTTPS request (business domain)
    CF->>Lambda: Forward encrypted payload
    Lambda->>Lambda: Validate TOTP window
    Lambda->>Lambda: Decrypt message
    Lambda->>Claude: Send decrypted prompt
    Claude-->>Lambda: AI response
    Lambda->>Lambda: Encrypt response
    Lambda->>DDB: Store encrypted history
    Lambda-->>CF: Encrypted response
    CF-->>Client: Forward response
    Client->>Client: Decrypt with TOTP key
    Client-->>User: Display AI response
```

### Security Layers Architecture

```mermaid
graph TD
    subgraph "Layer 7: Application Security"
        A7[Message Content Encryption]
        B7[Session Management]
        C7[Input Validation]
    end

    subgraph "Layer 6: Authentication"
        A6[TOTP Validation]
        B6[Time Window Checks]
        C6[Replay Protection]
    end

    subgraph "Layer 5: Cryptographic"
        A5[AES-256-GCM]
        B5[PBKDF2 Key Derivation]
        C5[Secure Random IVs]
    end

    subgraph "Layer 4: Transport"
        A4[TLS 1.3]
        B4[Certificate Pinning]
        C4[HSTS Headers]
    end

    subgraph "Layer 3: Network Obfuscation"
        A3[Business Domain Camouflage]
        B3[Traffic Pattern Randomization]
        C3[Legitimate API Mimicry]
    end

    subgraph "Layer 2: Infrastructure"
        A2[AWS Lambda Isolation]
        B2[VPC Security Groups]
        C2[CloudWatch Monitoring]
    end

    subgraph "Layer 1: Operational Security"
        A1[Domain Rotation Strategy]
        B1[Emergency Burn Procedures]
        C1[Audit Trail Management]
    end
```

### Deployment Topology

```mermaid
graph TB
    subgraph "Multi-Region Deployment"
        subgraph "Primary Region (us-east-1)"
            AG1[API Gateway]
            L1[Lambda Functions]
            DB1[(DynamoDB Primary)]
            CW1[CloudWatch]
        end

        subgraph "Secondary Region (eu-west-1)"
            AG2[API Gateway]
            L2[Lambda Functions]
            DB2[(DynamoDB Replica)]
            CW2[CloudWatch]
        end

        subgraph "Tertiary Region (ap-southeast-1)"
            AG3[API Gateway]
            L3[Lambda Functions]
            DB3[(DynamoDB Replica)]
            CW3[CloudWatch]
        end
    end

    subgraph "Global Services"
        CF[CloudFlare Global CDN]
        R53[Route 53 Health Checks]
        IAM[IAM Cross-Region Roles]
    end

    subgraph "Domain Strategy"
        D1[business-consulting.com]
        D2[market-analytics.net]
        D3[financial-reports.org]
        D4[logistics-solutions.co]
    end

    CF --> AG1
    CF --> AG2
    CF --> AG3
    R53 --> AG1
    R53 --> AG2
    R53 --> AG3

    D1 -.-> CF
    D2 -.-> CF
    D3 -.-> CF
    D4 -.-> CF
```

### Component Interaction Architecture

```mermaid
graph LR
    subgraph "Client Layer"
        PM[Postman]
        CE[Crypto Engine]
        TG[TOTP Generator]
    end

    subgraph "Proxy Layer"
        CF[CloudFlare]
        LB[Load Balancer]
        WAF[Web Application Firewall]
    end

    subgraph "Compute Layer"
        subgraph "Lambda Function"
            RH[Request Handler]
            TV[TOTP Validator]
            CD[Crypto Decoder]
            AI[Anthropic Interface]
            SR[Session Recorder]
        end
    end

    subgraph "Storage Layer"
        DDB[(DynamoDB)]
        S3[(S3 Backup)]
        CW[CloudWatch Logs]
    end

    PM --> CE
    CE --> TG
    TG --> CF
    CF --> LB
    LB --> WAF
    WAF --> RH
    RH --> TV
    TV --> CD
    CD --> AI
    AI --> SR
    SR --> DDB
    SR --> S3
    RH --> CW
```

### Encryption Flow Architecture

```mermaid
flowchart TD
    A[User Message] --> B[Generate TOTP Code]
    B --> C[Derive Encryption Key]
    C --> D[Generate Random IV]
    D --> E[AES-256-GCM Encrypt]
    E --> F[Create Authenticated Payload]
    F --> G[Base64 Encode]
    G --> H[Send HTTPS Request]

    H --> I[Lambda Receives Request]
    I --> J[Validate TOTP Window]
    J --> K[Derive Same Key]
    K --> L[Extract IV]
    L --> M[AES-256-GCM Decrypt]
    M --> N[Verify Authentication Tag]
    N --> O[Process Decrypted Message]

    O --> P[Send to Anthropic API]
    P --> Q[Receive AI Response]
    Q --> R[Generate New IV]
    R --> S[Encrypt Response]
    S --> T[Return Encrypted Data]

    style A fill:#ffeeee
    style H fill:#eeffee
    style P fill:#eeeeff
    style T fill:#ffffee
```

### Threat Model and Mitigations

```mermaid
graph TB
    subgraph "Threat Vectors"
        T1[Network Monitoring]
        T2[Traffic Analysis]
        T3[Pattern Recognition]
        T4[Domain Blocking]
        T5[Payload Inspection]
        T6[Timing Attacks]
    end

    subgraph "Mitigation Strategies"
        M1[Business Domain Camouflage]
        M2[Traffic Randomization]
        M3[Legitimate Request Patterns]
        M4[Domain Rotation]
        M5[End-to-End Encryption]
        M6[Variable Response Times]
    end

    T1 --> M1
    T2 --> M2
    T3 --> M3
    T4 --> M4
    T5 --> M5
    T6 --> M6

    style T1 fill:#ffcccc
    style T2 fill:#ffcccc
    style T3 fill:#ffcccc
    style T4 fill:#ffcccc
    style T5 fill:#ffcccc
    style T6 fill:#ffcccc

    style M1 fill:#ccffcc
    style M2 fill:#ccffcc
    style M3 fill:#ccffcc
    style M4 fill:#ccffcc
    style M5 fill:#ccffcc
    style M6 fill:#ccffcc
```

## Technical Architecture Details

### Lambda Function Architecture

```mermaid
graph TD
    subgraph "Lambda Execution Environment"
        subgraph "Handler Layer"
            H1[Chat Handler]
            H2[History Handler]
            H3[Health Handler]
        end

        subgraph "Service Layer"
            S1[Encryption Service]
            S2[TOTP Service]
            S3[Anthropic Service]
            S4[Storage Service]
        end

        subgraph "Utility Layer"
            U1[Logger]
            U2[Validator]
            U3[Error Handler]
        end

        subgraph "External Integrations"
            E1[DynamoDB Client]
            E2[Anthropic API Client]
            E3[CloudWatch Client]
        end
    end

    H1 --> S1
    H1 --> S2
    H1 --> S3
    H2 --> S4
    H3 --> U1

    S1 --> U2
    S2 --> U2
    S3 --> U3
    S4 --> E1

    S3 --> E2
    U1 --> E3
```

### Database Schema Architecture

```mermaid
erDiagram
    CHAT_SESSIONS {
        string sessionId PK
        string timestamp SK
        string userId
        string role
        string encryptedContent
        string iv
        string authTag
        number ttl
        timestamp createdAt
        timestamp updatedAt
    }

    DOMAIN_REGISTRY {
        string domainId PK
        string domainName
        string status
        timestamp lastUsed
        number hitCount
        string cloudflareZone
        timestamp expiryDate
    }

    TOTP_SECRETS {
        string userId PK
        string encryptedSecret
        string secretIv
        timestamp lastRotation
        number version
        string backupCodes
    }

    CHAT_SESSIONS ||--o{ DOMAIN_REGISTRY : "uses"
    CHAT_SESSIONS ||--|| TOTP_SECRETS : "authenticates"
```

### API Gateway Configuration

```mermaid
graph TD
    subgraph "API Gateway"
        subgraph "Resources"
            R1[/chat]
            R2[/history]
            R3[/health]
        end

        subgraph "Methods"
            M1[POST /chat]
            M2[GET /history]
            M3[GET /health]
        end

        subgraph "Integration"
            I1[Lambda Proxy Integration]
            I2[Request Validation]
            I3[Response Transformation]
        end

        subgraph "Security"
            SEC1[API Key Required]
            SEC2[Rate Limiting]
            SEC3[CORS Configuration]
        end
    end

    R1 --> M1
    R2 --> M2
    R3 --> M3

    M1 --> I1
    M2 --> I1
    M3 --> I1

    I1 --> SEC1
    I2 --> SEC2
    I3 --> SEC3
```

## Operational Architecture

### Monitoring and Alerting

```mermaid
graph TB
    subgraph "Metrics Collection"
        M1[Lambda Metrics]
        M2[API Gateway Metrics]
        M3[DynamoDB Metrics]
        M4[Custom Application Metrics]
    end

    subgraph "Log Aggregation"
        L1[Lambda Logs]
        L2[API Gateway Logs]
        L3[Application Logs]
        L4[Security Audit Logs]
    end

    subgraph "Dashboards"
        D1[System Health Dashboard]
        D2[Security Monitoring Dashboard]
        D3[Performance Dashboard]
        D4[Cost Optimization Dashboard]
    end

    subgraph "Alerting"
        A1[High Error Rate Alert]
        A2[Domain Block Detection]
        A3[Unusual Traffic Patterns]
        A4[TOTP Failure Spike]
    end

    M1 --> D1
    M2 --> D2
    M3 --> D3
    M4 --> D4

    L1 --> A1
    L2 --> A2
    L3 --> A3
    L4 --> A4
```

### Disaster Recovery Architecture

```mermaid
graph TB
    subgraph "Primary Region Failure"
        P1[Traffic Routing]
        P2[Health Check Failure]
        P3[Automatic Failover]
    end

    subgraph "Recovery Procedures"
        R1[DNS Failover]
        R2[Lambda Deployment]
        R3[Database Sync]
        R4[Domain Switching]
    end

    subgraph "Backup Systems"
        B1[Cross-Region Replication]
        B2[Configuration Backup]
        B3[Encrypted Data Archive]
        B4[Domain Pool Management]
    end

    P1 --> R1
    P2 --> R2
    P3 --> R3

    R1 --> B1
    R2 --> B2
    R3 --> B3
    R4 --> B4
```

## Security Architecture Deep Dive

### TOTP Implementation Details

The TOTP (Time-based One-Time Password) system forms the backbone of our security architecture:

1. **Secret Generation**: 32-byte cryptographically secure random secrets
2. **Time Window**: 30-second intervals with ±1 window tolerance
3. **Algorithm**: HMAC-SHA1 as per RFC 6238
4. **Key Derivation**: PBKDF2-SHA256 with 100,000 iterations
5. **Backup Codes**: 10 single-use recovery codes per user

### Encryption Protocol

```mermaid
graph LR
    subgraph "Encryption Process"
        A[Message] --> B[TOTP Code]
        B --> C[PBKDF2 Key Derivation]
        C --> D[AES-256-GCM]
        D --> E[Authenticated Ciphertext]
    end

    subgraph "Decryption Process"
        F[Ciphertext] --> G[TOTP Validation]
        G --> H[Key Derivation]
        H --> I[AES-256-GCM Decrypt]
        I --> J[Plaintext + Auth Verify]
    end
```

### Traffic Obfuscation Strategy

1. **Domain Camouflage**: Business-like domain names (consulting, analytics, reports)
2. **Request Patterns**: Mimic legitimate business API calls
3. **Timing Randomization**: Variable delays between requests
4. **Size Obfuscation**: Padding to normalize payload sizes
5. **Decoy Traffic**: Interspersed legitimate-looking requests

## Deployment Architecture Options

### Option 1: AWS Lambda (Recommended)

**Advantages:**

- Serverless scalability
- Built-in high availability
- Cost-effective for intermittent usage
- Regional deployment flexibility

**Components:**

- API Gateway for request routing
- Lambda functions for processing
- DynamoDB for session storage
- CloudWatch for monitoring

### Option 2: Vercel Serverless

**Advantages:**

- Simple deployment
- Global edge network
- Built-in SSL
- TypeScript support

**Components:**

- Vercel serverless functions
- Edge runtime
- Vercel KV for storage
- Analytics dashboard

### Option 3: Self-Hosted Docker

**Advantages:**

- Complete control
- Custom infrastructure
- No vendor lock-in
- Enhanced privacy

**Components:**

- Docker containers
- Nginx reverse proxy
- PostgreSQL database
- Prometheus monitoring

## Performance Architecture

### Optimization Strategies

1. **Cold Start Mitigation**

   - Provisioned concurrency for Lambda
   - Connection pooling
   - Minimal dependency loading

2. **Response Time Optimization**

   - Concurrent processing
   - Efficient encryption algorithms
   - Database query optimization

3. **Scalability Patterns**
   - Auto-scaling Lambda functions
   - DynamoDB on-demand pricing
   - Multi-region deployment

### Load Testing Architecture

```mermaid
graph TD
    subgraph "Load Testing Setup"
        LT1[Artillery.io Tests]
        LT2[Postman Collections]
        LT3[Custom Node.js Scripts]
    end

    subgraph "Test Scenarios"
        TS1[Normal Usage Patterns]
        TS2[Peak Traffic Simulation]
        TS3[Stress Testing]
        TS4[Security Attack Simulation]
    end

    subgraph "Metrics Collection"
        MC1[Response Times]
        MC2[Error Rates]
        MC3[Throughput]
        MC4[Resource Utilization]
    end

    LT1 --> TS1
    LT2 --> TS2
    LT3 --> TS3

    TS1 --> MC1
    TS2 --> MC2
    TS3 --> MC3
    TS4 --> MC4
```

## Cost Architecture

### Cost Optimization Strategy

1. **Serverless First**: Pay-per-use pricing model
2. **Resource Right-Sizing**: Optimal Lambda memory allocation
3. **Storage Optimization**: TTL-based data expiration
4. **Network Efficiency**: CloudFlare caching and compression

### Cost Monitoring

```mermaid
graph TB
    subgraph "Cost Tracking"
        CT1[AWS Cost Explorer]
        CT2[Custom Cost Alerts]
        CT3[Resource Tagging]
        CT4[Usage Analytics]
    end

    subgraph "Optimization Actions"
        OA1[Auto-scaling Adjustment]
        OA2[Reserved Capacity]
        OA3[Data Archival]
        OA4[Service Consolidation]
    end

    CT1 --> OA1
    CT2 --> OA2
    CT3 --> OA3
    CT4 --> OA4
```

## Compliance and Governance

### Security Compliance Framework

1. **Data Protection**

   - Encryption at rest and in transit
   - Data minimization principles
   - Automated data expiration

2. **Access Control**

   - Principle of least privilege
   - Multi-factor authentication
   - Audit trail maintenance

3. **Incident Response**
   - Automated threat detection
   - Emergency burn procedures
   - Forensic data collection

### Governance Structure

```mermaid
graph TD
    subgraph "Governance Levels"
        G1[Strategic Governance]
        G2[Operational Governance]
        G3[Technical Governance]
    end

    subgraph "Responsibilities"
        R1[Security Policy Definition]
        R2[Operational Procedures]
        R3[Technical Implementation]
    end

    subgraph "Controls"
        C1[Regular Audits]
        C2[Compliance Monitoring]
        C3[Risk Assessment]
    end

    G1 --> R1
    G2 --> R2
    G3 --> R3

    R1 --> C1
    R2 --> C2
    R3 --> C3
```

## Future Architecture Enhancements

### Planned Improvements

1. **Enhanced Obfuscation**

   - Machine learning-based traffic patterns
   - Dynamic domain generation
   - Advanced payload camouflage

2. **Performance Optimizations**

   - Edge computing deployment
   - Advanced caching strategies
   - Protocol optimizations

3. **Security Enhancements**
   - Zero-knowledge architecture
   - Homomorphic encryption
   - Quantum-resistant algorithms

### Scalability Roadmap

```mermaid
timeline
    title System Evolution Roadmap

    Phase 1 : MVP Deployment
           : Basic TOTP encryption
           : Single region deployment
           : Postman client

    Phase 2 : Enhanced Security
           : Multi-domain strategy
           : Traffic obfuscation
           : Emergency procedures

    Phase 3 : Global Scale
           : Multi-region deployment
           : Advanced monitoring
           : AI-driven optimization

    Phase 4 : Next Generation
           : Quantum-resistant crypto
           : Zero-knowledge proofs
           : Autonomous operations
```

This architecture documentation provides a comprehensive overview of the Gaza Secure AI Chat Proxy system, covering all aspects from high-level design to detailed technical implementation. The system is designed to be bulletproof, professional, and capable of maintaining secure communications even under the most restrictive corporate environments.
