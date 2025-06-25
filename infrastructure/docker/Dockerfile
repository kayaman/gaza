# Multi-stage Dockerfile for Secure AI Chat Proxy
# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git

# Copy package files
COPY backend/lambda/package*.json ./
COPY backend/shared ./shared/

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY backend/lambda/src ./src/

# Stage 2: Production stage
FROM node:18-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    ca-certificates \
    && update-ca-certificates

# Copy built application from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/src ./src
COPY --from=builder --chown=nodejs:nodejs /app/shared ./shared
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Create necessary directories
RUN mkdir -p /app/logs /app/tmp && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV LOG_LEVEL=info

# Start the application
CMD ["node", "src/server.js"]