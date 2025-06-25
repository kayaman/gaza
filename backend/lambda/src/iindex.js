/**
 * AWS Lambda Entry Point for Secure AI Chat Proxy
 * Handles encrypted chat requests with TOTP-based authentication
 */

const { chatHandler } = require('./handlers/chat');
const { historyHandler } = require('./handlers/history');
const { healthHandler } = require('./handlers/health');
const logger = require('./utils/logger');
const { validateRequest } = require('./utils/validator');
const { handleError } = require('./utils/errors');

// CORS headers for all responses
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
  'Content-Type': 'application/json',
};

/**
 * Main Lambda handler function
 * Routes requests to appropriate handlers based on action
 */
exports.handler = async (event, context) => {
  // Set up context
  context.callbackWaitsForEmptyEventLoop = false;

  const startTime = Date.now();
  const requestId = context.awsRequestId || 'local-' + Date.now();

  // Initialize logger with request context
  logger.setContext({
    requestId,
    functionName: context.functionName,
    functionVersion: context.functionVersion,
  });

  logger.info('Request received', {
    httpMethod: event.httpMethod,
    path: event.path,
    headers: event.headers ? Object.keys(event.headers) : [],
    sourceIp: event.requestContext?.identity?.sourceIp,
  });

  try {
    // Handle preflight OPTIONS requests
    if (event.httpMethod === 'OPTIONS') {
      return {
        statusCode: 200,
        headers: CORS_HEADERS,
        body: '',
      };
    }

    // Validate HTTP method
    if (!['GET', 'POST'].includes(event.httpMethod)) {
      return createErrorResponse(405, 'Method not allowed', requestId);
    }

    // Parse request body for POST requests
    let body = {};
    if (event.httpMethod === 'POST' && event.body) {
      try {
        body = JSON.parse(event.body);
      } catch (error) {
        logger.error('Invalid JSON in request body', { error: error.message });
        return createErrorResponse(400, 'Invalid JSON in request body', requestId);
      }
    }

    // Route based on path or action
    const path = event.path || '/';
    const action = body.action || getActionFromPath(path);

    logger.info('Routing request', { action, path });

    let response;

    switch (action) {
      case 'health':
        response = await healthHandler(event, context);
        break;

      case 'chat':
        // Validate required fields for chat
        const chatValidation = validateRequest(body, [
          'sessionId',
          'encryptedMessage',
          'iv',
          'totpCode',
        ]);
        if (!chatValidation.isValid) {
          return createErrorResponse(
            400,
            `Missing required fields: ${chatValidation.missingFields.join(', ')}`,
            requestId
          );
        }
        response = await chatHandler(body, context);
        break;

      case 'getHistory':
      case 'history':
        // Validate required fields for history
        const historyValidation = validateRequest(body, ['sessionId', 'totpCode']);
        if (!historyValidation.isValid) {
          return createErrorResponse(
            400,
            `Missing required fields: ${historyValidation.missingFields.join(', ')}`,
            requestId
          );
        }
        response = await historyHandler(body, context);
        break;

      default:
        logger.warn('Unknown action requested', { action, path });
        return createErrorResponse(404, 'Unknown action or endpoint', requestId);
    }

    // Add CORS headers to response
    response.headers = {
      ...CORS_HEADERS,
      ...response.headers,
    };

    // Log successful response
    const duration = Date.now() - startTime;
    logger.info('Request completed successfully', {
      statusCode: response.statusCode,
      duration,
      responseSize: response.body ? response.body.length : 0,
    });

    return response;
  } catch (error) {
    // Handle unexpected errors
    logger.error('Unhandled error in Lambda handler', {
      error: error.message,
      stack: error.stack,
      duration: Date.now() - startTime,
    });

    return handleError(error, requestId);
  }
};

/**
 * Create standardized error response
 */
function createErrorResponse(statusCode, message, requestId) {
  const response = {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      success: false,
      error: message,
      requestId,
      timestamp: new Date().toISOString(),
    }),
  };

  logger.error('Error response created', {
    statusCode,
    message,
    requestId,
  });

  return response;
}

/**
 * Extract action from request path
 */
function getActionFromPath(path) {
  // Remove leading slash and extract first segment
  const segments = path.replace(/^\/+/, '').split('/');
  const firstSegment = segments[0];

  // Map common paths to actions
  const pathMappings = {
    health: 'health',
    chat: 'chat',
    history: 'getHistory',
    messages: 'getHistory',
    '': 'health', // Root path defaults to health check
  };

  return pathMappings[firstSegment] || firstSegment;
}

/**
 * Graceful shutdown handler
 */
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, performing graceful shutdown');
  // Close database connections, cleanup resources, etc.
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, performing graceful shutdown');
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', error => {
  logger.error('Uncaught exception', {
    error: error.message,
    stack: error.stack,
  });
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled promise rejection', {
    reason: reason?.message || reason,
    promise: promise.toString(),
  });
});

module.exports = { handler: exports.handler };
