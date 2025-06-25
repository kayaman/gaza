#!/bin/bash
# Docker Management Scripts for Secure AI Chat Proxy

# =============================================================================
# setup.sh - Initial Docker environment setup
# =============================================================================
setup_docker_environment() {
    echo "🚀 Setting up Docker environment for Secure AI Chat Proxy..."
    
    # Check if Docker and Docker Compose are installed
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Create necessary directories
    mkdir -p {logs,data,config,ssl,backups}
    mkdir -p {prometheus,grafana/provisioning,fluentd/conf}
    
    # Copy environment file
    if [ ! -f .env ]; then
        cp .env.docker .env
        echo "📝 Created .env file. Please update with your actual values."
    fi
    
    # Generate SSL certificates for development
    generate_dev_ssl_certs
    
    # Create configuration files
    create_config_files
    
    # Set proper permissions
    chmod +x scripts/*.sh
    chmod 600 .env
    
    echo "✅ Docker environment setup complete!"
    echo "📖 Next steps:"
    echo "   1. Update .env file with your API keys"
    echo "   2. Run: ./start.sh"
}

# =============================================================================
# start.sh - Start the complete Docker environment
# =============================================================================
start_environment() {
    echo "🚀 Starting Secure AI Chat Proxy environment..."
    
    # Load environment variables
    source .env
    
    # Build and start containers
    docker-compose build --no-cache
    docker-compose up -d
    
    # Wait for services to be ready
    echo "⏳ Waiting for services to start..."
    sleep 10
    
    # Initialize DynamoDB table
    initialize_dynamodb
    
    # Check service health
    check_service_health
    
    echo "✅ Environment started successfully!"
    echo "🌐 Service URLs:"
    echo "   - Main API: https://localhost/chat"
    echo "   - Health Check: http://localhost/health"
    echo "   - Grafana: http://localhost:3001"
    echo "   - Prometheus: http://localhost:9090"
    echo "   - DynamoDB Admin: http://localhost:8080/dynamodb"
}

# =============================================================================
# stop.sh - Stop the Docker environment
# =============================================================================
stop_environment() {
    echo "🛑 Stopping Secure AI Chat Proxy environment..."
    
    docker-compose down
    
    echo "✅ Environment stopped."
}

# =============================================================================
# restart.sh - Restart specific services
# =============================================================================
restart_service() {
    local service=${1:-"secure-chat-proxy"}
    
    echo "🔄 Restarting service: $service"
    
    docker-compose restart $service
    
    # Wait a moment for the service to restart
    sleep 5
    
    # Check health
    if [ "$service" = "secure-chat-proxy" ]; then
        check_app_health
    fi
    
    echo "✅ Service $service restarted."
}

# =============================================================================
# logs.sh - View logs for services
# =============================================================================
view_logs() {
    local service=${1:-"secure-chat-proxy"}
    local lines=${2:-100}
    
    echo "📋 Viewing logs for $service (last $lines lines):"
    
    docker-compose logs --tail=$lines -f $service
}

# =============================================================================
# backup.sh - Backup data and configurations
# =============================================================================
backup_data() {
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_dir="./backups/$backup_name"
    
    echo "💾 Creating backup: $backup_name"
    
    mkdir -p $backup_dir
    
    # Backup DynamoDB data
    docker exec dynamodb-local aws dynamodb scan \
        --table-name encrypted-chat-sessions \
        --endpoint-url http://localhost:8000 \
        --region us-east-1 \
        > $backup_dir/dynamodb-data.json
    
    # Backup Redis data
    docker exec redis-cache redis-cli --raw BGSAVE
    docker cp redis-cache:/data/dump.rdb $backup_dir/redis-dump.rdb
    
    # Backup configurations
    cp -r config $backup_dir/
    cp .env $backup_dir/env.backup
    
    # Backup logs
    cp -r logs $backup_dir/
    
    # Create archive
    tar -czf $backup_dir.tar.gz -C ./backups $backup_name
    rm -rf $backup_dir
    
    echo "✅ Backup created: $backup_dir.tar.gz"
}

# =============================================================================
# restore.sh - Restore from backup
# =============================================================================
restore_data() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        echo "❌ Please specify backup file: ./restore.sh backup-file.tar.gz"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo "❌ Backup file not found: $backup_file"
        exit 1
    fi
    
    echo "🔄 Restoring from backup: $backup_file"
    
    # Extract backup
    local temp_dir=$(mktemp -d)
    tar -xzf $backup_file -C $temp_dir
    local backup_name=$(basename $backup_file .tar.gz)
    local backup_dir="$temp_dir/$backup_name"
    
    # Stop services
    docker-compose down
    
    # Restore configurations
    cp -r $backup_dir/config/* config/ 2>/dev/null || true
    cp $backup_dir/env.backup .env 2>/dev/null || true
    
    # Start services
    docker-compose up -d dynamodb-local redis
    sleep 10
    
    # Restore DynamoDB data
    if [ -f "$backup_dir/dynamodb-data.json" ]; then
        echo "📦 Restoring DynamoDB data..."
        # Note: In production, implement proper DynamoDB restore logic
        echo "⚠️  DynamoDB restore requires manual implementation"
    fi
    
    # Restore Redis data
    if [ -f "$backup_dir/redis-dump.rdb" ]; then
        echo "📦 Restoring Redis data..."
        docker cp $backup_dir/redis-dump.rdb redis-cache:/data/dump.rdb
        docker-compose restart redis
    fi
    
    # Start all services
    docker-compose up -d
    
    # Cleanup
    rm -rf $temp_dir
    
    echo "✅ Restore completed!"
}

# =============================================================================
# clean.sh - Clean up Docker environment
# =============================================================================
clean_environment() {
    local deep_clean=${1:-false}
    
    echo "🧹 Cleaning Docker environment..."
    
    # Stop and remove containers
    docker-compose down -v
    
    # Remove images
    docker-compose down --rmi all
    
    if [ "$deep_clean" = "true" ]; then
        echo "🔥 Performing deep clean..."
        
        # Remove volumes
        docker volume prune -f
        
        # Remove unused networks
        docker network prune -f
        
        # Remove build cache
        docker system prune -f
        
        # Remove local data directories
        rm -rf data/* logs/* backups/*
        
        echo "✅ Deep clean completed!"
    else
        echo "✅ Basic clean completed!"
        echo "💡 Run with 'true' parameter for deep clean: ./clean.sh true"
    fi
}

# =============================================================================
# monitor.sh - Monitor system health and performance
# =============================================================================
monitor_system() {
    echo "📊 System Monitoring Dashboard"
    echo "==============================="
    
    # Container status
    echo "🐳 Container Status:"
    docker-compose ps
    echo ""
    
    # Resource usage
    echo "💻 Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    echo ""
    
    # Disk usage
    echo "💾 Disk Usage:"
    docker system df
    echo ""
    
    # Service health checks
    echo "🏥 Health Checks:"
    check_service_health
    echo ""
    
    # Recent logs (errors only)
    echo "🚨 Recent Errors:"
    docker-compose logs --tail=10 2>&1 | grep -i error || echo "No recent errors found"
}

# =============================================================================
# dev.sh - Development mode operations
# =============================================================================
dev_mode() {
    local action=${1:-"start"}
    
    case $action in
        "start")
            echo "🔧 Starting development environment..."
            docker-compose --profile dev up -d
            docker-compose exec dev-tools bash
            ;;
        "test")
            echo "🧪 Running tests..."
            docker-compose exec secure-chat-proxy npm test
            ;;
        "lint")
            echo "🔍 Running linter..."
            docker-compose exec secure-chat-proxy npm run lint
            ;;
        "build")
            echo "🏗️  Building application..."
            docker-compose build --no-cache secure-chat-proxy
            ;;
        "shell")
            echo "🐚 Opening development shell..."
            docker-compose exec dev-tools bash
            ;;
        *)
            echo "❓ Usage: ./dev.sh [start|test|lint|build|shell]"
            ;;
    esac
}

# =============================================================================
# Helper Functions
# =============================================================================

generate_dev_ssl_certs() {
    echo "🔐 Generating development SSL certificates..."
    
    if [ ! -d "ssl" ]; then
        mkdir ssl
    fi
    
    # Generate self-signed certificate for development
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/key.pem \
        -out ssl/cert.pem \
        -subj "/C=US/ST=Development/L=Local/O=SecureChat/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:*.consulting-metrics.com,DNS:*.project-sync.net,IP:127.0.0.1"
    
    echo "✅ SSL certificates generated for development"
}

create_config_files() {
    echo "📝 Creating configuration files..."
    
    # Redis configuration
    cat > config/redis.conf << EOF
# Redis configuration for Secure AI Chat Proxy
bind 127.0.0.1
port 6379
timeout 0
save 900 1
save 300 10
save 60 10000
maxmemory 256mb
maxmemory-policy allkeys-lru
EOF
    
    # Prometheus configuration
    cat > prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  
scrape_configs:
  - job_name: 'secure-chat-proxy'
    static_configs:
      - targets: ['secure-chat-proxy:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s
    
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: '/nginx_status'
    scrape_interval: 30s
EOF
    
    # Fluentd configuration
    mkdir -p fluentd/conf
    cat > fluentd/conf/fluent.conf << EOF
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<match secure-chat.**>
  @type file
  path /var/log/fluentd/secure-chat
  append true
  time_slice_format %Y%m%d
  time_slice_wait 10m
  time_format %Y%m%dT%H%M%S%z
</match>
EOF
    
    echo "✅ Configuration files created"
}

initialize_dynamodb() {
    echo "🗄️  Initializing DynamoDB table..."
    
    # Wait for DynamoDB to be ready
    until curl -s http://localhost:8000/ > /dev/null; do
        echo "Waiting for DynamoDB..."
        sleep 2
    done
    
    # Create table
    docker exec dynamodb-local aws dynamodb create-table \
        --table-name encrypted-chat-sessions \
        --attribute-definitions \
            AttributeName=sessionId,AttributeType=S \
            AttributeName=timestamp,AttributeType=S \
        --key-schema \
            AttributeName=sessionId,KeyType=HASH \
            AttributeName=timestamp,KeyType=RANGE \
        --provisioned-throughput \
            ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --endpoint-url http://localhost:8000 \
        --region us-east-1 \
        2>/dev/null || echo "Table may already exist"
    
    echo "✅ DynamoDB initialized"
}

check_service_health() {
    echo "🏥 Checking service health..."
    
    # Main application
    check_app_health
    
    # DynamoDB
    if curl -s http://localhost:8000/ > /dev/null; then
        echo "✅ DynamoDB: Healthy"
    else
        echo "❌ DynamoDB: Unhealthy"
    fi
    
    # Redis
    if docker exec redis-cache redis-cli ping 2>/dev/null | grep -q PONG; then
        echo "✅ Redis: Healthy"
    else
        echo "❌ Redis: Unhealthy"
    fi
    
    # Nginx
    if curl -s http://localhost/health > /dev/null; then
        echo "✅ Nginx: Healthy"
    else
        echo "❌ Nginx: Unhealthy"
    fi
}

check_app_health() {
    if curl -s http://localhost:3000/health > /dev/null; then
        echo "✅ Application: Healthy"
    else
        echo "❌ Application: Unhealthy"
    fi
}

# =============================================================================
# Main Script Router
# =============================================================================

# Determine which function to call based on script name
script_name=$(basename "$0")

case $script_name in
    "setup.sh")
        setup_docker_environment "$@"
        ;;
    "start.sh")
        start_environment "$@"
        ;;
    "stop.sh")
        stop_environment "$@"
        ;;
    "restart.sh")
        restart_service "$@"
        ;;
    "logs.sh")
        view_logs "$@"
        ;;
    "backup.sh")
        backup_data "$@"
        ;;
    "restore.sh")
        restore_data "$@"
        ;;
    "clean.sh")
        clean_environment "$@"
        ;;
    "monitor.sh")
        monitor_system "$@"
        ;;
    "dev.sh")
        dev_mode "$@"
        ;;
    *)
        echo "❓ Available commands:"
        echo "   ./setup.sh    - Initial environment setup"
        echo "   ./start.sh    - Start all services"
        echo "   ./stop.sh     - Stop all services"
        echo "   ./restart.sh  - Restart service"
        echo "   ./logs.sh     - View service logs"
        echo "   ./backup.sh   - Backup data"
        echo "   ./restore.sh  - Restore from backup"
        echo "   ./clean.sh    - Clean environment"
        echo "   ./monitor.sh  - Monitor system health"
        echo "   ./dev.sh      - Development operations"
        ;;
esac