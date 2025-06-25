# Docker Infrastructure Guide

## Overview

This directory contains a complete Docker-based infrastructure for the Secure AI Chat Proxy, including development, testing, and production-ready configurations.

## 📁 Directory Structure

```
infrastructure/docker/
├── Dockerfile                    # Production application container
├── Dockerfile.dev               # Development environment container
├── docker-compose.yml           # Complete service orchestration
├── nginx.conf                   # Reverse proxy configuration
├── .env.docker                  # Environment variables template
├── scripts/                     # Management scripts
│   ├── setup.sh                # Initial environment setup
│   ├── start.sh                # Start all services
│   ├── stop.sh                 # Stop all services
│   ├── restart.sh              # Restart specific services
│   ├── logs.sh                 # View service logs
│   ├── backup.sh               # Backup data and configurations
│   ├── restore.sh              # Restore from backup
│   ├── clean.sh                # Clean up environment
│   ├── monitor.sh              # System monitoring
│   └── dev.sh                  # Development operations
├── config/                     # Configuration files
│   ├── redis.conf              # Redis configuration
│   ├── prometheus.yml          # Prometheus monitoring
│   └── fluent.conf             # Log aggregation
├── ssl/                        # SSL certificates (generated)
├── logs/                       # Application logs
├── data/                       # Persistent data
└── backups/                    # Backup storage
```

## 🚀 Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- 10GB disk space

### 1. Initial Setup

```bash
# Navigate to docker directory
cd infrastructure/docker

# Run initial setup
chmod +x scripts/*.sh
./scripts/setup.sh

# Edit environment variables
nano .env
```

### 2. Start Environment

```bash
# Start all services
./scripts/start.sh

# Monitor startup
./scripts/logs.sh secure-chat-proxy
```

### 3. Verify Installation

```bash
# Check service health
./scripts/monitor.sh

# Test API endpoint
curl -k https://localhost/health
```

## 🛠️ Service Architecture

### Core Services

```yaml
secure-chat-proxy:     # Main application (Node.js)
├── Port: 3000
├── Health: /health
└── API: /chat

nginx:                 # Reverse proxy & SSL termination
├── Port: 80 (HTTP)
├── Port: 443 (HTTPS)
└── Config: nginx.conf

dynamodb-local:        # Local DynamoDB instance
├── Port: 8000
├── Data: ./data/dynamodb
└── Admin: localhost:8080/dynamodb

redis:                 # Caching & session storage
├── Port: 6379
├── Password: configured in .env
└── Data: ./data/redis
```

### Monitoring Stack

```yaml
prometheus:            # Metrics collection
├── Port: 9090
├── Config: prometheus.yml
└── Retention: 200h

grafana:              # Visualization dashboard
├── Port: 3001
├── User: admin
├── Password: configured in .env
└── Data: ./data/grafana

fluentd:              # Log aggregation
├── Port: 24224
├── Config: fluentd/conf/
└── Logs: ./logs/fluentd
```

## 🔧 Configuration

### Environment Variables

```bash
# Core Application
ANTHROPIC_API_KEY=your-api-key-here
TOTP_SECRET=your-totp-secret-here
NODE_ENV=production

# Database
DYNAMODB_TABLE=encrypted-chat-sessions
REDIS_PASSWORD=secure-password

# Security
SESSION_TTL_DAYS=30
RATE_LIMIT_MAX_REQUESTS=100

# Domains
PRIMARY_DOMAIN=api.consulting-metrics.com
BACKUP_DOMAINS=webhook.project-sync.net,analytics.performance-data.org

# Monitoring
GRAFANA_PASSWORD=secure-grafana-password
```

### SSL Configuration

```bash
# Development (self-signed)
./scripts/setup.sh  # Generates certificates automatically

# Production (Let's Encrypt)
# 1. Update nginx.conf with your domains
# 2. Use certbot to generate certificates
# 3. Mount certificates in docker-compose.yml
```

## 📊 Monitoring & Observability

### Health Checks

```bash
# Application health
curl http://localhost:3000/health

# All services health
./scripts/monitor.sh

# Service logs
./scripts/logs.sh [service-name]
```

### Metrics Dashboard

- **Grafana**: http://localhost:3001
- **Prometheus**: http://localhost:9090
- **DynamoDB Admin**: http://localhost:8080/dynamodb

### Key Metrics

- Request/response latency
- TOTP validation success/failure rates
- Encryption/decryption performance
- DynamoDB read/write capacity
- Redis cache hit rates
- Nginx request rates and response codes

## 🔐 Security Features

### Container Security

```yaml
Security Measures:
├── Non-root user execution
├── Minimal base images (Alpine)
├── Read-only root filesystems
├── Resource limits and quotas
├── Network isolation
└── Secret management via environment variables
```

### Network Security

```yaml
Network Configuration:
├── Custom bridge network (172.20.0.0/16)
├── Service-to-service communication only
├── External access via Nginx proxy only
├── SSL/TLS termination at proxy
└── Internal traffic encryption
```

### Data Security

```yaml
Data Protection:
├── Encryption at rest (DynamoDB)
├── Encrypted inter-service communication
├── SSL certificates for HTTPS
├── Redis password authentication
└── Volume encryption (production)
```

## 🛡️ Production Deployment

### Pre-Production Checklist

- [ ] Update all passwords in .env
- [ ] Configure real SSL certificates
- [ ] Set up external monitoring
- [ ] Configure log shipping
- [ ] Enable backup automation
- [ ] Security scan containers
- [ ] Performance testing
- [ ] Disaster recovery testing

### Production Configuration

```yaml
# docker-compose.prod.yml
version: "3.8"
services:
  secure-chat-proxy:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          memory: 256M
    restart: always
    logging:
      driver: "fluentd"
      options:
        fluentd-address: "fluentd:24224"
        tag: "secure-chat.app"
```

### Scaling Considerations

```bash
# Horizontal scaling
docker-compose up --scale secure-chat-proxy=3

# Load balancing
# Nginx automatically load balances across replicas

# Database scaling
# Use AWS DynamoDB in production for auto-scaling
```

## 🔄 Operations

### Daily Operations

```bash
# Morning health check
./scripts/monitor.sh

# Check logs for errors
./scripts/logs.sh secure-chat-proxy | grep ERROR

# Monitor resource usage
docker stats
```

### Backup & Recovery

```bash
# Create backup
./scripts/backup.sh

# Scheduled backups (add to crontab)
0 2 * * * /path/to/scripts/backup.sh

# Restore from backup
./scripts/restore.sh backup-20250624-020000.tar.gz
```

### Updates & Maintenance

```bash
# Update application
git pull
./scripts/restart.sh secure-chat-proxy

# Update all containers
docker-compose pull
docker-compose up -d

# Clean old images
./scripts/clean.sh
```

## 🐛 Troubleshooting

### Common Issues

#### Service Won't Start

```bash
# Check logs
./scripts/logs.sh [service-name]

# Check resource usage
docker stats

# Restart service
./scripts/restart.sh [service-name]
```

#### SSL Certificate Issues

```bash
# Regenerate development certificates
rm -rf ssl/
./scripts/setup.sh

# Check certificate validity
openssl x509 -in ssl/cert.pem -text -noout
```

#### Database Connection Issues

```bash
# Check DynamoDB
curl http://localhost:8000/

# Initialize tables
./scripts/start.sh  # Reinitializes tables

# Check Redis
docker exec redis-cache redis-cli ping
```

#### Performance Issues

```bash
# Monitor resources
./scripts/monitor.sh

# Check container logs
./scripts/logs.sh secure-chat-proxy

# Scale services
docker-compose up --scale secure-chat-proxy=2
```

### Debug Mode

```bash
# Enable debug logging
echo "LOG_LEVEL=debug" >> .env
./scripts/restart.sh secure-chat-proxy

# Development shell access
./scripts/dev.sh shell

# Run tests
./scripts/dev.sh test
```

## 📈 Performance Tuning

### Application Optimization

```yaml
Node.js Optimization:
├── NODE_ENV=production
├── Memory limits: 512MB
├── CPU limits: 1.0 core
├── Keep-alive connections
└── Clustering enabled
```

### Database Optimization

```yaml
DynamoDB Optimization:
├── Read capacity: Auto-scaling
├── Write capacity: Auto-scaling
├── Global secondary indexes
└── TTL for automatic cleanup
```

### Cache Optimization

```yaml
Redis Optimization:
├── Memory policy: allkeys-lru
├── Max memory: 256MB
├── Persistence: RDB snapshots
└── Connection pooling
```

## 🔒 Security Hardening

### Container Hardening

```bash
# Scan for vulnerabilities
docker scan secure-chat-proxy:latest

# Update base images regularly
docker-compose build --no-cache --pull

# Use specific image tags (not 'latest')
# Review and minimize installed packages
```

### Network Hardening

```bash
# Firewall rules (iptables)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 3001 -j DROP  # Block external Grafana access

# Use secrets management
# Implement certificate rotation
# Enable audit logging
```

## 📚 Additional Resources

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [DynamoDB Local Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html)
- [Redis Configuration Guide](https://redis.io/topics/config)
- [Prometheus Monitoring](https://prometheus.io/docs/)

## 🤝 Contributing

When contributing to the Docker infrastructure:

1. Test changes in development environment
2. Update documentation
3. Follow security best practices
4. Test backup/restore procedures
5. Validate monitoring and alerting

For questions or issues, refer to the main project documentation or create an issue in the repository.
