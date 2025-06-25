# Architecture Diagrams

This document contains comprehensive architecture diagrams for the Secure AI Chat Proxy system using Mermaid notation.

## 1. High-Level System Architecture

```mermaid
graph TB
    subgraph "Corporate Network"
        User[👤 User]
        Postman[📧 Postman Client]
        TOTP[📱 TOTP App<br/>Google Authenticator]
        Firewall[🛡️ Corporate Firewall<br/>DPI & Monitoring]
    end

    subgraph "Public Internet"
        CDN[☁️ CloudFlare Proxy<br/>SSL Termination]
        DNS[🌐 Business Domains<br/>api.consulting-metrics.com<br/>webhook.project-sync.net]
    end

    subgraph "AWS Cloud Infrastructure"
        WAF[🛡️ WAF<br/>Rate Limiting]
        API[🔌 API Gateway<br/>REST API]
        Lambda[⚡ Lambda Function<br/>Node.js 18.x]
        DDB[🗄️ DynamoDB<br/>Encrypted Storage]
        KMS[🔐 KMS<br/>Encryption Keys]
        CW[📊 CloudWatch<br/>Monitoring]
    end

    subgraph "AI Service"
        Anthropic[🤖 Anthropic Claude API<br/>ai.anthropic.com]
    end

    User --> Postman
    User --> TOTP
    Postman --> Firewall
    TOTP -.-> Postman
    Firewall --> DNS
    DNS --> CDN
    CDN --> WAF
    WAF --> API
    API --> Lambda
    Lambda --> DDB
    Lambda --> Anthropic
    DDB --> KMS
    Lambda --> CW

    classDef corporate fill:#e1f5fe
    classDef public fill:#f3e5f5
    classDef aws fill:#fff3e0
    classDef ai fill:#e8f5e8

    class User,Postman,TOTP,Firewall corporate
    class CDN,DNS public
    class WAF,API,Lambda,DDB,KMS,CW aws
    class Anthropic ai
```

## 2. Security Architecture & Data Flow

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant P as 📧 Postman
    participant T as 📱 TOTP App
    participant F as 🛡️ Firewall
    participant C as ☁️ CloudFlare
    participant W as 🛡️ WAF
    participant A as 🔌 API Gateway
    participant L as ⚡ Lambda
    participant D as 🗄️ DynamoDB
    participant AI as 🤖 Claude API

    Note over U,AI: 🔐 End-to-End Encrypted Communication Flow

    U->>T: Generate TOTP Code
    T-->>U: 6-digit Code (30s validity)

    U->>P: Input: Message + TOTP
    Note over P: 🔒 Client-side AES-256-GCM Encryption
    P->>P: Encrypt(message, TOTP_key)

    P->>F: HTTPS POST (encrypted payload)
    Note over F: 🔍 Deep Packet Inspection<br/>Only sees: business domain + encrypted blob

    F->>C: Route to business domain
    C->>W: Forward with SSL termination
    W->>A: Rate limit & geo-block check
    A->>L: Invoke with encrypted payload

    Note over L: 🔓 Server-side Processing
    L->>L: Validate TOTP (±30s window)
    L->>L: Decrypt message using TOTP
    L->>D: Retrieve conversation history
    D-->>L: Encrypted history
    L->>L: Decrypt history with stored TOTPs

    L->>AI: Send decrypted message (HTTPS)
    AI-->>L: Plain text response

    L->>L: Encrypt response with original TOTP
    L->>D: Store encrypted conversation

    L-->>A: Encrypted response + TOTP used
    A-->>W: HTTP response
    W-->>C: Forward response
    C-->>F: Encrypted response
    F-->>P: Encrypted response (corporate sees encrypted blob)

    Note over P: 🔓 Client-side Decryption
    P->>P: Decrypt(response, original_TOTP)
    P-->>U: Plain text AI response

    Note over U,AI: 🛡️ Security: Corporate IT cannot decrypt any content
```

## 3. Encryption & Key Management Flow

```mermaid
graph TD
    subgraph "TOTP Generation (RFC 6238)"
        Secret[🔑 Base32 Secret<br/>160-bit entropy]
        Time[⏰ Current Time<br/>30-second intervals]
        HMAC[🔐 HMAC-SHA1<br/>Time + Secret]
        Code[🔢 6-digit TOTP<br/>123456]

        Secret --> HMAC
        Time --> HMAC
        HMAC --> Code
    end
```
