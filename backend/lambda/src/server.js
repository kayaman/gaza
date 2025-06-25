/**
 * Standalone Server - Express.js server wrapper for Docker deployment
 * Allows running the Lambda function as a standalone HTTP server
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { handler } = require('./index');
const logger = require('./utils/logger');
const { createErrorResponse } = require('./utils/errors');

// Server configuration
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const NODE_ENV = process.env.NODE_ENV || 'development';

/**
 * Create Express application with middleware
 */
function createApp() {
  const app = express();

  // Trust proxy for proper IP forwarding
  app.set('trust proxy', true);

  // Security middleware
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:', 'https:'],
          connectSrc: ["'self'"],
          fontSrc: ["'self'"],
          objectSrc: ["'none'"],
          mediaSrc: ["'self'"],
          frameSrc: ["'none'"],
        },
      },
      crossOriginEmbedderPolicy: false,
    })
  );

  // CORS configuration
  app.use(
    cors({
      origin: process.env.CORS_ORIGIN || '*',
      methods: ['GET', 'POST', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
      credentials: false,
      maxAge: 86400, // 24 hours
    })
  );

  // Compression middleware
  app.use(
    compression({
      threshold: 1024,
      level: 6,
    })
  );

  // Rate limiting
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: process.env.RATE_LIMIT_MAX || 100,
    message: {
      error: 'Too many requests',
      retryAfter: '15 minutes',
    },
    standardHeaders: true,
    legacyHeaders: false,
    skip: req => {
      // Skip rate limiting for health checks
      return req.path === '/health';
    },
  });
  app.use(limiter);

  // Request parsing middleware
  app.use(
    express.json({
      limit: process.env.MAX_REQUEST_SIZE || '10mb',
      strict: true,
    })
  );

  app.use(
    express.urlencoded({
      extended: false,
      limit: '1mb',
    })
  );

  // Request logging middleware
  app.use((req, res, next) => {
    const startTime = Date.now();
    const requestId = generateRequestId();

    // Set request context
    logger.setContext({
      requestId,
      method: req.method,
      path: req.path,
      userAgent: req.get('User-Agent'),
      sourceIp: req.ip,
    });

    logger.request(req.method, req.path, {
      headers: Object.keys(req.headers),
      query: Object.keys(req.query),
      bodySize: req.body ? JSON.stringify(req.body).length : 0,
    });

    // Capture response
    const originalSend = res.send;
    res.send = function (body) {
      const duration = Date.now() - startTime;
      logger.response(res.statusCode, duration, {
        responseSize: body ? body.length : 0,
      });
      originalSend.call(this, body);
    };

    next();
  });

  return app;
}

/**
 * Convert Express request to Lambda event format
 */
function convertToLambdaEvent(req) {
  return {
    httpMethod: req.method,
    path: req.path,
    pathParameters: req.params || {},
    queryStringParameters: req.query || {},
    headers: req.headers || {},
    body: req.body ? JSON.stringify(req.body) : null,
    isBase64Encoded: false,
    requestContext: {
      requestId: logger.getContext().requestId,
      identity: {
        sourceIp: req.ip,
        userAgent: req.get('User-Agent'),
      },
      httpMethod: req.method,
      path: req.path,
    },
  };
}

/**
 * Convert Lambda response to Express response
 */
function convertFromLambdaResponse(lambdaResponse, res) {
  // Set status code
  res.status(lambdaResponse.statusCode || 200);

  // Set headers
  if (lambdaResponse.headers) {
    Object.entries(lambdaResponse.headers).forEach(([key, value]) => {
      res.set(key, value);
    });
  }

  // Send body
  if (lambdaResponse.body) {
    if (lambdaResponse.isBase64Encoded) {
      res.send(Buffer.from(lambdaResponse.body, 'base64'));
    } else {
      res.send(lambdaResponse.body);
    }
  } else {
    res.end();
  }
}

/**
 * Generate request ID
 */
function generateRequestId() {
  return `req-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Lambda handler wrapper middleware
 */
function lambdaWrapper(req, res, next) {
  const lambdaEvent = convertToLambdaEvent(req);
  const lambdaContext = {
    awsRequestId: logger.getContext().requestId,
    functionName: 'secure-chat-proxy-server',
    functionVersion: process.env.SERVICE_VERSION || '1.0.0',
    invokedFunctionArn: 'local:function:secure-chat-proxy-server',
    memoryLimitInMB: '256',
    remainingTimeInMillis: () => 30000,
  };

  handler(lambdaEvent, lambdaContext)
    .then(lambdaResponse => {
      convertFromLambdaResponse(lambdaResponse, res);
    })
    .catch(error => {
      logger.error('Lambda handler error', {
        error: error.message,
        stack: error.stack,
      });

      const errorResponse = createErrorResponse(
        500,
        'Internal server error',
        lambdaContext.awsRequestId
      );

      convertFromLambdaResponse(errorResponse, res);
    });
}

/**
 * Setup routes
 */
function setupRoutes(app) {
  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'secure-ai-chat-proxy',
      version: process.env.SERVICE_VERSION || '1.0.0',
      environment: NODE_ENV,
      uptime: Math.round(process.uptime()),
      memory: process.memoryUsage(),
    });
  });

  // Readiness probe
  app.get('/ready', (req, res) => {
    // Add any readiness checks here (database connectivity, etc.)
    res.json({
      status: 'ready',
      timestamp: new Date().toISOString(),
    });
  });

  // Liveness probe
  app.get('/live', (req, res) => {
    res.json({
      status: 'alive',
      timestamp: new Date().toISOString(),
      pid: process.pid,
    });
  });

  // Metrics endpoint (for Prometheus)
  app.get('/metrics', (req, res) => {
    const metrics = generateMetrics();
    res.set('Content-Type', 'text/plain');
    res.send(metrics);
  });

  // Main API routes - delegate to Lambda handler
  app.all('/chat', lambdaWrapper);
  app.all('/history', lambdaWrapper);
  app.all('/api/*', lambdaWrapper);

  // Catch-all route for Lambda handler
  app.all('*', lambdaWrapper);

  // Error handling middleware
  app.use((error, req, res, next) => {
    logger.error('Express error handler', {
      error: error.message,
      stack: error.stack,
      path: req.path,
      method: req.method,
    });

    res.status(500).json({
      error: 'Internal server error',
      requestId: logger.getContext().requestId,
      timestamp: new Date().toISOString(),
    });
  });

  // 404 handler
  app.use((req, res) => {
    res.status(404).json({
      error: 'Not found',
      path: req.path,
      method: req.method,
      timestamp: new Date().toISOString(),
    });
  });
}

/**
 * Generate Prometheus metrics
 */
function generateMetrics() {
  const memUsage = process.memoryUsage();
  const cpuUsage = process.cpuUsage();

  return `
# HELP nodejs_memory_rss_bytes Resident set size in bytes
# TYPE nodejs_memory_rss_bytes gauge
nodejs_memory_rss_bytes ${memUsage.rss}

# HELP nodejs_memory_heap_used_bytes Heap used in bytes
# TYPE nodejs_memory_heap_used_bytes gauge
nodejs_memory_heap_used_bytes ${memUsage.heapUsed}

# HELP nodejs_memory_heap_total_bytes Heap total in bytes
# TYPE nodejs_memory_heap_total_bytes gauge
nodejs_memory_heap_total_bytes ${memUsage.heapTotal}

# HELP nodejs_cpu_user_seconds_total User CPU time in seconds
# TYPE nodejs_cpu_user_seconds_total counter
nodejs_cpu_user_seconds_total ${cpuUsage.user / 1000000}

# HELP nodejs_cpu_system_seconds_total System CPU time in seconds
# TYPE nodejs_cpu_system_seconds_total counter
nodejs_cpu_system_seconds_total ${cpuUsage.system / 1000000}

# HELP nodejs_uptime_seconds Process uptime in seconds
# TYPE nodejs_uptime_seconds gauge
nodejs_uptime_seconds ${process.uptime()}
`.trim();
}

/**
 * Start the server
 */
function startServer() {
  const app = createApp();
  setupRoutes(app);

  const server = app.listen(PORT, HOST, () => {
    logger.info('Server started', {
      port: PORT,
      host: HOST,
      environment: NODE_ENV,
      nodeVersion: process.version,
      pid: process.pid,
    });
  });

  // Graceful shutdown handling
  const gracefulShutdown = signal => {
    logger.info(`Received ${signal}, performing graceful shutdown`);

    server.close(() => {
      logger.info('HTTP server closed');
      process.exit(0);
    });

    // Force close after 10 seconds
    setTimeout(() => {
      logger.error('Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  // Handle uncaught exceptions
  process.on('uncaughtException', error => {
    logger.error('Uncaught exception', { error: error.message, stack: error.stack });
    process.exit(1);
  });

  process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled rejection', { reason, promise: promise.toString() });
    process.exit(1);
  });

  return server;
}

// Start server if this file is run directly
if (require.main === module) {
  startServer();
}

module.exports = {
  createApp,
  startServer,
  convertToLambdaEvent,
  convertFromLambdaResponse,
};
