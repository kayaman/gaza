/**
 * Health Check Handler - System health monitoring and diagnostics
 * Provides comprehensive health status for all system components
 */

const { testStorage } = require('../services/storage');
const { testAnthropicAPI } = require('../services/anthropic');
const { testTOTP } = require('../services/totp');
const { testEncryption } = require('../services/encryption');
const logger = require('../utils/logger');
const { createSuccessResponse, createErrorResponse } = require('../utils/errors');

/**
 * Basic health check - lightweight endpoint for load balancer probes
 */
async function healthHandler(event, context) {
  const requestId = context.awsRequestId;
  const startTime = Date.now();

  try {
    logger.info('Health check requested', {
      userAgent: event.headers ? event.headers['User-Agent'] : 'unknown',
      sourceIp: event.requestContext?.identity?.sourceIp,
    });

    // Basic system checks
    const memoryUsage = process.memoryUsage();
    const uptime = process.uptime();
    const nodeVersion = process.version;

    const healthData = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'secure-ai-chat-proxy',
      version: process.env.SERVICE_VERSION || '1.0.0',
      environment: process.env.NODE_ENV || 'unknown',
      region: process.env.AWS_REGION || 'unknown',
      uptime: Math.round(uptime),
      nodeVersion,
      memory: {
        rss: Math.round(memoryUsage.rss / 1024 / 1024), // MB
        heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024), // MB
        heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024), // MB
        external: Math.round(memoryUsage.external / 1024 / 1024), // MB
      },
      requestId,
      responseTime: Date.now() - startTime,
    };

    logger.info('Health check completed', {
      status: 'healthy',
      responseTime: healthData.responseTime,
      memoryUsedMB: healthData.memory.heapUsed,
    });

    return createSuccessResponse(healthData, requestId);
  } catch (error) {
    const responseTime = Date.now() - startTime;

    logger.error('Health check failed', {
      error: error.message,
      responseTime,
    });

    const errorData = {
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      requestId,
      responseTime,
    };

    return createErrorResponse(500, 'Health check failed', requestId, errorData);
  }
}

/**
 * Detailed health check - comprehensive system diagnostics
 */
async function detailedHealthHandler(event, context) {
  const requestId = context.awsRequestId;
  const startTime = Date.now();

  try {
    logger.info('Detailed health check requested');

    // Run all component health checks in parallel
    const [storageHealth, anthropicHealth, totpHealth, encryptionHealth] = await Promise.allSettled(
      [testStorage(), testAnthropicAPI(), testTOTP(), testEncryption()]
    );

    // Evaluate overall health status
    const components = {
      storage: evaluateComponentHealth(storageHealth, 'Storage'),
      anthropic: evaluateComponentHealth(anthropicHealth, 'Anthropic API'),
      totp: evaluateComponentHealth(totpHealth, 'TOTP Authentication'),
      encryption: evaluateComponentHealth(encryptionHealth, 'Encryption'),
    };

    // Determine overall status
    const allHealthy = Object.values(components).every(comp => comp.status === 'healthy');
    const overallStatus = allHealthy ? 'healthy' : 'degraded';

    // Get system metrics
    const systemMetrics = getSystemMetrics();
    const environmentInfo = getEnvironmentInfo();

    const healthData = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      service: 'secure-ai-chat-proxy',
      version: process.env.SERVICE_VERSION || '1.0.0',
      components,
      systemMetrics,
      environment: environmentInfo,
      checks: {
        total: 4,
        passed: Object.values(components).filter(c => c.status === 'healthy').length,
        failed: Object.values(components).filter(c => c.status === 'unhealthy').length,
      },
      requestId,
      responseTime: Date.now() - startTime,
    };

    logger.info('Detailed health check completed', {
      overallStatus,
      passedChecks: healthData.checks.passed,
      failedChecks: healthData.checks.failed,
      responseTime: healthData.responseTime,
    });

    const statusCode = overallStatus === 'healthy' ? 200 : 503;
    return {
      statusCode,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
      body: JSON.stringify(healthData, null, 2),
    };
  } catch (error) {
    const responseTime = Date.now() - startTime;

    logger.error('Detailed health check failed', {
      error: error.message,
      stack: error.stack,
      responseTime,
    });

    return createErrorResponse(500, 'Detailed health check failed', requestId);
  }
}

/**
 * Component-specific health check
 */
async function componentHealthHandler(component, context) {
  const requestId = context.awsRequestId;
  const startTime = Date.now();

  try {
    logger.info('Component health check requested', { component });

    let testResult;
    let componentName;

    switch (component.toLowerCase()) {
      case 'storage':
      case 'dynamodb':
        testResult = await testStorage();
        componentName = 'Storage';
        break;

      case 'anthropic':
      case 'ai':
        testResult = await testAnthropicAPI();
        componentName = 'Anthropic API';
        break;

      case 'totp':
      case 'auth':
        testResult = await testTOTP();
        componentName = 'TOTP Authentication';
        break;

      case 'encryption':
      case 'crypto':
        testResult = await testEncryption();
        componentName = 'Encryption';
        break;

      default:
        return createErrorResponse(400, `Unknown component: ${component}`, requestId);
    }

    const componentHealth = {
      component: componentName,
      status: testResult.success ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      details: testResult,
      responseTime: Date.now() - startTime,
      requestId,
    };

    logger.info('Component health check completed', {
      component: componentName,
      status: componentHealth.status,
      responseTime: componentHealth.responseTime,
    });

    const statusCode = testResult.success ? 200 : 503;
    return {
      statusCode,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
      body: JSON.stringify(componentHealth, null, 2),
    };
  } catch (error) {
    logger.error('Component health check failed', {
      component,
      error: error.message,
      responseTime: Date.now() - startTime,
    });

    return createErrorResponse(500, 'Component health check failed', requestId);
  }
}

/**
 * Configuration health check - verify environment variables and settings
 */
async function configHealthHandler(event, context) {
  const requestId = context.awsRequestId;

  try {
    logger.info('Configuration health check requested');

    const requiredEnvVars = ['ANTHROPIC_API_KEY', 'TOTP_SECRET', 'DYNAMODB_TABLE'];

    const optionalEnvVars = ['AWS_REGION', 'NODE_ENV', 'LOG_LEVEL', 'SESSION_TTL_DAYS'];

    const configStatus = {
      required: {},
      optional: {},
      warnings: [],
      errors: [],
    };

    // Check required environment variables
    for (const envVar of requiredEnvVars) {
      const value = process.env[envVar];
      configStatus.required[envVar] = {
        configured: !!value,
        length: value ? value.length : 0,
        masked: value ? maskSensitiveValue(value) : null,
      };

      if (!value) {
        configStatus.errors.push(`Missing required environment variable: ${envVar}`);
      }
    }

    // Check optional environment variables
    for (const envVar of optionalEnvVars) {
      const value = process.env[envVar];
      configStatus.optional[envVar] = {
        configured: !!value,
        value: value || null,
      };
    }

    // Validate configuration values
    validateConfiguration(configStatus);

    const isHealthy = configStatus.errors.length === 0;

    const healthData = {
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      configuration: configStatus,
      summary: {
        requiredConfigured: Object.values(configStatus.required).filter(c => c.configured).length,
        requiredTotal: requiredEnvVars.length,
        optionalConfigured: Object.values(configStatus.optional).filter(c => c.configured).length,
        optionalTotal: optionalEnvVars.length,
        warnings: configStatus.warnings.length,
        errors: configStatus.errors.length,
      },
      requestId,
    };

    logger.info('Configuration health check completed', {
      status: healthData.status,
      errors: configStatus.errors.length,
      warnings: configStatus.warnings.length,
    });

    const statusCode = isHealthy ? 200 : 503;
    return {
      statusCode,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
      body: JSON.stringify(healthData, null, 2),
    };
  } catch (error) {
    logger.error('Configuration health check failed', {
      error: error.message,
    });

    return createErrorResponse(500, 'Configuration health check failed', requestId);
  }
}

/**
 * Evaluate component health from Promise result
 */
function evaluateComponentHealth(promiseResult, componentName) {
  if (promiseResult.status === 'fulfilled') {
    const result = promiseResult.value;
    return {
      status: result.success ? 'healthy' : 'unhealthy',
      message: result.success
        ? 'Component is functioning correctly'
        : result.error || 'Component test failed',
      lastChecked: new Date().toISOString(),
      details: result,
    };
  } else {
    return {
      status: 'unhealthy',
      message: `Component test threw an error: ${promiseResult.reason?.message || 'Unknown error'}`,
      lastChecked: new Date().toISOString(),
      error: promiseResult.reason?.message,
    };
  }
}

/**
 * Get system metrics
 */
function getSystemMetrics() {
  const memoryUsage = process.memoryUsage();
  const cpuUsage = process.cpuUsage();

  return {
    memory: {
      rss: Math.round(memoryUsage.rss / 1024 / 1024),
      heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024),
      heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024),
      external: Math.round(memoryUsage.external / 1024 / 1024),
      arrayBuffers: Math.round(memoryUsage.arrayBuffers / 1024 / 1024),
    },
    cpu: {
      user: Math.round(cpuUsage.user / 1000), // microseconds to milliseconds
      system: Math.round(cpuUsage.system / 1000),
    },
    uptime: Math.round(process.uptime()),
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
  };
}

/**
 * Get environment information
 */
function getEnvironmentInfo() {
  return {
    nodeEnv: process.env.NODE_ENV || 'unknown',
    awsRegion: process.env.AWS_REGION || 'unknown',
    serviceVersion: process.env.SERVICE_VERSION || '1.0.0',
    logLevel: process.env.LOG_LEVEL || 'info',
    dynamoDbTable: process.env.DYNAMODB_TABLE || 'not-configured',
    sessionTtlDays: process.env.SESSION_TTL_DAYS || '30',
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  };
}

/**
 * Validate configuration values
 */
function validateConfiguration(configStatus) {
  // Validate TOTP secret format
  const totpSecret = process.env.TOTP_SECRET;
  if (totpSecret) {
    if (totpSecret.length < 16) {
      configStatus.warnings.push('TOTP secret is shorter than recommended (minimum 16 characters)');
    }
    if (!/^[A-Z2-7]+$/.test(totpSecret)) {
      configStatus.warnings.push('TOTP secret contains invalid Base32 characters');
    }
  }

  // Validate Anthropic API key format
  const anthropicKey = process.env.ANTHROPIC_API_KEY;
  if (anthropicKey) {
    if (!anthropicKey.startsWith('sk-ant-')) {
      configStatus.warnings.push('Anthropic API key format appears invalid');
    }
    if (anthropicKey.length < 100) {
      configStatus.warnings.push('Anthropic API key appears too short');
    }
  }

  // Validate session TTL
  const sessionTtl = process.env.SESSION_TTL_DAYS;
  if (sessionTtl) {
    const ttlDays = parseInt(sessionTtl);
    if (isNaN(ttlDays) || ttlDays < 1 || ttlDays > 365) {
      configStatus.warnings.push('SESSION_TTL_DAYS should be between 1 and 365');
    }
  }

  // Validate AWS region
  const awsRegion = process.env.AWS_REGION;
  if (awsRegion && !/^[a-z]{2}-[a-z]+-\d+$/.test(awsRegion)) {
    configStatus.warnings.push('AWS_REGION format appears invalid');
  }
}

/**
 * Mask sensitive values for logging
 */
function maskSensitiveValue(value) {
  if (!value || value.length < 8) {
    return '***';
  }

  const start = value.substring(0, 4);
  const end = value.substring(value.length - 4);
  const masked = '*'.repeat(Math.min(value.length - 8, 20));

  return `${start}${masked}${end}`;
}

module.exports = {
  healthHandler,
  detailedHealthHandler,
  componentHealthHandler,
  configHealthHandler,
};
/**
 * Error Handling Utility - Standardized error responses and handling
 * Provides consistent error formatting and security-conscious error handling
 */

const logger = require('./logger');

/**
 * Standard error codes and messages
 */
const ERROR_CODES = {
  // Client errors (4xx)
  BAD_REQUEST: {
    code: 'BAD_REQUEST',
    statusCode: 400,
    message: 'Invalid request format or parameters',
  },
  UNAUTHORIZED: {
    code: 'UNAUTHORIZED',
    statusCode: 401,
    message: 'Authentication required or invalid credentials',
  },
  FORBIDDEN: {
    code: 'FORBIDDEN',
    statusCode: 403,
    message: 'Access denied',
  },
  NOT_FOUND: {
    code: 'NOT_FOUND',
    statusCode: 404,
    message: 'Resource not found',
  },
  METHOD_NOT_ALLOWED: {
    code: 'METHOD_NOT_ALLOWED',
    statusCode: 405,
    message: 'HTTP method not allowed',
  },
  CONFLICT: {
    code: 'CONFLICT',
    statusCode: 409,
    message: 'Resource conflict',
  },
  VALIDATION_ERROR: {
    code: 'VALIDATION_ERROR',
    statusCode: 422,
    message: 'Input validation failed',
  },
  RATE_LIMITED: {
    code: 'RATE_LIMITED',
    statusCode: 429,
    message: 'Too many requests',
  },

  // Server errors (5xx)
  INTERNAL_ERROR: {
    code: 'INTERNAL_ERROR',
    statusCode: 500,
    message: 'Internal server error',
  },
  NOT_IMPLEMENTED: {
    code: 'NOT_IMPLEMENTED',
    statusCode: 501,
    message: 'Feature not implemented',
  },
  BAD_GATEWAY: {
    code: 'BAD_GATEWAY',
    statusCode: 502,
    message: 'External service error',
  },
  SERVICE_UNAVAILABLE: {
    code: 'SERVICE_UNAVAILABLE',
    statusCode: 503,
    message: 'Service temporarily unavailable',
  },
  GATEWAY_TIMEOUT: {
    code: 'GATEWAY_TIMEOUT',
    statusCode: 504,
    message: 'External service timeout',
  },

  // Application-specific errors
  TOTP_INVALID: {
    code: 'TOTP_INVALID',
    statusCode: 401,
    message: 'Invalid or expired TOTP code',
  },
  ENCRYPTION_ERROR: {
    code: 'ENCRYPTION_ERROR',
    statusCode: 400,
    message: 'Encryption or decryption failed',
  },
  STORAGE_ERROR: {
    code: 'STORAGE_ERROR',
    statusCode: 500,
    message: 'Database operation failed',
  },
  AI_SERVICE_ERROR: {
    code: 'AI_SERVICE_ERROR',
    statusCode: 502,
    message: 'AI service unavailable',
  },
  SESSION_NOT_FOUND: {
    code: 'SESSION_NOT_FOUND',
    statusCode: 404,
    message: 'Session not found',
  },
  CONFIGURATION_ERROR: {
    code: 'CONFIGURATION_ERROR',
    statusCode: 500,
    message: 'Server configuration error',
  },
};

/**
 * Custom error classes
 */
class AppError extends Error {
  constructor(errorCode, message = null, details = null) {
    const errorDef = ERROR_CODES[errorCode] || ERROR_CODES.INTERNAL_ERROR;
    super(message || errorDef.message);

    this.name = 'AppError';
    this.code = errorDef.code;
    this.statusCode = errorDef.statusCode;
    this.details = details;
    this.isOperational = true;

    Error.captureStackTrace(this, AppError);
  }
}

class ValidationError extends AppError {
  constructor(message, validationDetails = null) {
    super('VALIDATION_ERROR', message, validationDetails);
    this.name = 'ValidationError';
  }
}

class AuthenticationError extends AppError {
  constructor(message = null) {
    super('UNAUTHORIZED', message);
    this.name = 'AuthenticationError';
  }
}

class TOTPError extends AppError {
  constructor(message = null) {
    super('TOTP_INVALID', message);
    this.name = 'TOTPError';
  }
}

class EncryptionError extends AppError {
  constructor(message = null) {
    super('ENCRYPTION_ERROR', message);
    this.name = 'EncryptionError';
  }
}

class StorageError extends AppError {
  constructor(message = null, details = null) {
    super('STORAGE_ERROR', message, details);
    this.name = 'StorageError';
  }
}

class AIServiceError extends AppError {
  constructor(message = null, details = null) {
    super('AI_SERVICE_ERROR', message, details);
    this.name = 'AIServiceError';
  }
}

/**
 * Create standardized success response
 * @param {Object} data - Response data
 * @param {string} requestId - Request ID for correlation
 * @param {number} statusCode - HTTP status code (default: 200)
 * @returns {Object} - Lambda response object
 */
function createSuccessResponse(data, requestId, statusCode = 200) {
  const response = {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-ID': requestId,
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
    body: JSON.stringify({
      success: true,
      requestId,
      timestamp: new Date().toISOString(),
      ...data,
    }),
  };

  logger.debug('Success response created', {
    statusCode,
    requestId,
    responseSize: response.body.length,
  });

  return response;
}

/**
 * Create standardized error response
 * @param {number} statusCode - HTTP status code
 * @param {string} message - Error message
 * @param {string} requestId - Request ID for correlation
 * @param {Object} details - Additional error details (optional)
 * @param {string} errorCode - Error code (optional)
 * @returns {Object} - Lambda response object
 */
function createErrorResponse(statusCode, message, requestId, details = null, errorCode = null) {
  // Sanitize error message to prevent information leakage
  const sanitizedMessage = sanitizeErrorMessage(message, statusCode);

  const errorBody = {
    success: false,
    error: {
      code: errorCode || getErrorCodeFromStatus(statusCode),
      message: sanitizedMessage,
      statusCode,
    },
    requestId,
    timestamp: new Date().toISOString(),
  };

  // Add details only in development or for specific error types
  if (details && shouldIncludeDetails(statusCode)) {
    errorBody.error.details = sanitizeErrorDetails(details);
  }

  const response = {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-ID': requestId,
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
    body: JSON.stringify(errorBody),
  };

  logger.error('Error response created', {
    statusCode,
    message: sanitizedMessage,
    requestId,
    hasDetails: !!details,
  });

  return response;
}

/**
 * Handle errors and convert to appropriate response
 * @param {Error} error - Error object
 * @param {string} requestId - Request ID for correlation
 * @returns {Object} - Lambda response object
 */
function handleError(error, requestId) {
  logger.error(
    'Handling error',
    {
      errorName: error.name,
      errorMessage: error.message,
      errorCode: error.code,
      statusCode: error.statusCode,
      requestId,
    },
    error
  );

  // Handle known application errors
  if (error instanceof AppError) {
    return createErrorResponse(
      error.statusCode,
      error.message,
      requestId,
      error.details,
      error.code
    );
  }

  // Handle validation errors from validator
  if (error.name === 'ValidationError' || (error.errors && Array.isArray(error.errors))) {
    return createErrorResponse(
      422,
      'Input validation failed',
      requestId,
      { validationErrors: error.errors || [error.message] },
      'VALIDATION_ERROR'
    );
  }

  // Handle AWS SDK errors
  if (error.code && error.statusCode) {
    return createErrorResponse(
      error.statusCode,
      getAWSErrorMessage(error),
      requestId,
      null,
      error.code
    );
  }

  // Handle HTTP errors
  if (error.statusCode && error.statusCode >= 400) {
    return createErrorResponse(
      error.statusCode,
      error.message || 'HTTP error',
      requestId,
      null,
      getErrorCodeFromStatus(error.statusCode)
    );
  }

  // Handle timeout errors
  if (error.code === 'ENOTFOUND' || error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
    return createErrorResponse(502, 'External service unavailable', requestId, null, 'BAD_GATEWAY');
  }

  // Handle generic Node.js errors
  if (error.code) {
    logger.warn('Unhandled Node.js error', {
      errorCode: error.code,
      errorMessage: error.message,
      requestId,
    });
  }

  // Default to internal server error
  return createErrorResponse(500, 'Internal server error', requestId, null, 'INTERNAL_ERROR');
}

/**
 * Sanitize error message to prevent information leakage
 * @param {string} message - Original error message
 * @param {number} statusCode - HTTP status code
 * @returns {string} - Sanitized message
 */
function sanitizeErrorMessage(message, statusCode) {
  if (!message || typeof message !== 'string') {
    return 'An error occurred';
  }

  // For server errors (5xx), use generic messages to prevent information leakage
  if (statusCode >= 500) {
    const genericMessages = {
      500: 'Internal server error',
      502: 'External service error',
      503: 'Service temporarily unavailable',
      504: 'Request timeout',
    };

    return genericMessages[statusCode] || 'Server error';
  }

  // For client errors (4xx), allow more specific messages but sanitize them
  return message
    .replace(/[\r\n]/g, ' ')
    .replace(/\s+/g, ' ')
    .substring(0, 200) // Limit message length
    .trim();
}

/**
 * Sanitize error details to prevent sensitive information leakage
 * @param {any} details - Error details
 * @returns {any} - Sanitized details
 */
function sanitizeErrorDetails(details) {
  if (!details) {
    return null;
  }

  if (typeof details === 'string') {
    return sanitizeErrorMessage(details, 400);
  }

  if (Array.isArray(details)) {
    return details.map(item => sanitizeErrorDetails(item));
  }

  if (typeof details === 'object') {
    const sanitized = {};
    const allowedKeys = [
      'field',
      'code',
      'message',
      'validation',
      'constraint',
      'expected',
      'actual',
      'path',
      'index',
      'limit',
    ];

    for (const [key, value] of Object.entries(details)) {
      if (allowedKeys.includes(key) || key.startsWith('validation')) {
        sanitized[key] = sanitizeErrorDetails(value);
      }
    }

    return sanitized;
  }

  return details;
}

/**
 * Determine if error details should be included in response
 * @param {number} statusCode - HTTP status code
 * @returns {boolean} - Whether to include details
 */
function shouldIncludeDetails(statusCode) {
  // Include details for client errors in development
  if (process.env.NODE_ENV === 'development' && statusCode >= 400 && statusCode < 500) {
    return true;
  }

  // Include details for validation errors
  if (statusCode === 422) {
    return true;
  }

  // Don't include details for server errors in production
  return false;
}

/**
 * Get error code from HTTP status code
 * @param {number} statusCode - HTTP status code
 * @returns {string} - Error code
 */
function getErrorCodeFromStatus(statusCode) {
  const statusToCode = {
    400: 'BAD_REQUEST',
    401: 'UNAUTHORIZED',
    403: 'FORBIDDEN',
    404: 'NOT_FOUND',
    405: 'METHOD_NOT_ALLOWED',
    409: 'CONFLICT',
    422: 'VALIDATION_ERROR',
    429: 'RATE_LIMITED',
    500: 'INTERNAL_ERROR',
    501: 'NOT_IMPLEMENTED',
    502: 'BAD_GATEWAY',
    503: 'SERVICE_UNAVAILABLE',
    504: 'GATEWAY_TIMEOUT',
  };

  return statusToCode[statusCode] || 'UNKNOWN_ERROR';
}

/**
 * Get user-friendly message for AWS errors
 * @param {Error} error - AWS error
 * @returns {string} - User-friendly message
 */
function getAWSErrorMessage(error) {
  const awsErrorMessages = {
    ValidationException: 'Invalid request parameters',
    ResourceNotFoundException: 'Resource not found',
    ConditionalCheckFailedException: 'Resource conflict',
    ProvisionedThroughputExceededException: 'Service temporarily busy',
    ThrottlingException: 'Request rate too high',
    AccessDeniedException: 'Access denied',
    UnauthorizedOperation: 'Unauthorized operation',
    InvalidParameterValue: 'Invalid parameter value',
    MissingParameter: 'Missing required parameter',
  };

  return awsErrorMessages[error.code] || error.message || 'AWS service error';
}

/**
 * Create rate limit error response
 * @param {string} requestId - Request ID
 * @param {Object} rateLimitInfo - Rate limit information
 * @returns {Object} - Lambda response object
 */
function createRateLimitResponse(requestId, rateLimitInfo) {
  const response = createErrorResponse(
    429,
    'Too many requests',
    requestId,
    {
      retryAfter: rateLimitInfo.retryAfter,
      limit: rateLimitInfo.limit,
      remaining: rateLimitInfo.remaining,
      resetTime: rateLimitInfo.resetTime,
    },
    'RATE_LIMITED'
  );

  // Add rate limit headers
  response.headers['Retry-After'] = Math.ceil(rateLimitInfo.retryAfter / 1000);
  response.headers['X-RateLimit-Limit'] = rateLimitInfo.limit;
  response.headers['X-RateLimit-Remaining'] = rateLimitInfo.remaining;
  response.headers['X-RateLimit-Reset'] = rateLimitInfo.resetTime;

  return response;
}

/**
 * Create validation error response
 * @param {string} requestId - Request ID
 * @param {Array} validationErrors - Array of validation errors
 * @returns {Object} - Lambda response object
 */
function createValidationResponse(requestId, validationErrors) {
  return createErrorResponse(
    422,
    'Input validation failed',
    requestId,
    { validationErrors },
    'VALIDATION_ERROR'
  );
}

/**
 * Log and handle uncaught exceptions
 * @param {Error} error - Uncaught error
 * @param {string} source - Source of the error
 */
function handleUncaughtError(error, source = 'uncaught') {
  logger.error(
    'Uncaught error detected',
    {
      source,
      errorName: error.name,
      errorMessage: error.message,
      stack: error.stack,
    },
    error
  );

  // In production, you might want to send alerts here
  if (process.env.NODE_ENV === 'production') {
    // Send to monitoring service
    // e.g., sendToMonitoring(error, source);
  }
}

/**
 * Wrap async functions with error handling
 * @param {Function} fn - Async function to wrap
 * @returns {Function} - Wrapped function
 */
function asyncErrorHandler(fn) {
  return async (...args) => {
    try {
      return await fn(...args);
    } catch (error) {
      logger.error(
        'Async function error',
        {
          functionName: fn.name,
          error: error.message,
          stack: error.stack,
        },
        error
      );
      throw error;
    }
  };
}

/**
 * Create error for missing environment variables
 * @param {string} varName - Environment variable name
 * @returns {AppError} - Configuration error
 */
function createConfigError(varName) {
  return new AppError('CONFIGURATION_ERROR', `Missing required environment variable: ${varName}`, {
    variable: varName,
  });
}

/**
 * Create error for invalid TOTP
 * @param {string} reason - Reason for TOTP failure
 * @returns {TOTPError} - TOTP error
 */
function createTOTPError(reason = 'Invalid or expired TOTP code') {
  return new TOTPError(reason);
}

/**
 * Create error for encryption failures
 * @param {string} operation - Encryption operation that failed
 * @param {string} reason - Reason for failure
 * @returns {EncryptionError} - Encryption error
 */
function createEncryptionError(operation, reason) {
  return new EncryptionError(`${operation} failed: ${reason}`);
}

/**
 * Create error for storage operations
 * @param {string} operation - Storage operation that failed
 * @param {string} reason - Reason for failure
 * @returns {StorageError} - Storage error
 */
function createStorageError(operation, reason) {
  return new StorageError(`Storage ${operation} failed: ${reason}`);
}

/**
 * Create error for AI service failures
 * @param {string} reason - Reason for AI service failure
 * @param {Object} details - Additional error details
 * @returns {AIServiceError} - AI service error
 */
function createAIServiceError(reason, details = null) {
  return new AIServiceError(reason, details);
}

/**
 * Retry wrapper with exponential backoff
 * @param {Function} operation - Operation to retry
 * @param {Object} options - Retry options
 * @returns {Promise} - Operation result
 */
async function retryWithBackoff(operation, options = {}) {
  const {
    maxRetries = 3,
    initialDelay = 1000,
    maxDelay = 10000,
    backoffFactor = 2,
    retryCondition = error => error.statusCode >= 500,
  } = options;

  let lastError;
  let delay = initialDelay;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      // Check if we should retry
      if (attempt === maxRetries || !retryCondition(error)) {
        throw error;
      }

      logger.warn('Operation failed, retrying', {
        attempt,
        maxRetries,
        delay,
        error: error.message,
        shouldRetry: retryCondition(error),
      });

      // Wait before next attempt
      await new Promise(resolve => setTimeout(resolve, delay));

      // Increase delay for next attempt
      delay = Math.min(delay * backoffFactor, maxDelay);
    }
  }

  throw lastError;
}

/**
 * Error boundary for Lambda functions
 * @param {Function} handler - Lambda handler function
 * @returns {Function} - Wrapped handler with error boundary
 */
function withErrorBoundary(handler) {
  return async (event, context) => {
    const requestId = context.awsRequestId || 'unknown';

    try {
      // Set up error context
      logger.setContext({
        requestId,
        functionName: context.functionName,
        functionVersion: context.functionVersion,
      });

      const result = await handler(event, context);

      logger.info('Handler completed successfully', {
        statusCode: result.statusCode,
        requestId,
      });

      return result;
    } catch (error) {
      logger.error(
        'Handler error caught by error boundary',
        {
          error: error.message,
          stack: error.stack,
          requestId,
        },
        error
      );

      return handleError(error, requestId);
    } finally {
      // Clean up context
      logger.clearContext();
    }
  };
}

/**
 * Performance monitoring wrapper
 * @param {Function} operation - Operation to monitor
 * @param {string} operationName - Name of the operation
 * @returns {Function} - Wrapped operation
 */
function withPerformanceMonitoring(operation, operationName) {
  return async (...args) => {
    const timer = logger.startTimer(operationName);

    try {
      const result = await operation(...args);
      timer({ success: true });
      return result;
    } catch (error) {
      timer({
        success: false,
        error: error.message,
        errorCode: error.code,
      });
      throw error;
    }
  };
}

/**
 * Circuit breaker pattern implementation
 */
class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeout = options.resetTimeout || 60000; // 1 minute
    this.monitoringPeriod = options.monitoringPeriod || 300000; // 5 minutes

    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.failureCount = 0;
    this.lastFailureTime = null;
    this.successCount = 0;
  }

  async execute(operation) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime < this.resetTimeout) {
        throw new AppError('SERVICE_UNAVAILABLE', 'Circuit breaker is OPEN');
      } else {
        this.state = 'HALF_OPEN';
        this.successCount = 0;
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    this.failureCount = 0;

    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= 3) {
        // Require 3 successes to close
        this.state = 'CLOSED';
      }
    }
  }

  onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
      logger.warn('Circuit breaker opened', {
        failureCount: this.failureCount,
        threshold: this.failureThreshold,
      });
    }
  }

  getState() {
    return {
      state: this.state,
      failureCount: this.failureCount,
      lastFailureTime: this.lastFailureTime,
      successCount: this.successCount,
    };
  }
}

/**
 * Health check error response
 * @param {string} component - Component that failed health check
 * @param {string} reason - Reason for failure
 * @param {string} requestId - Request ID
 * @returns {Object} - Health check error response
 */
function createHealthCheckError(component, reason, requestId) {
  return createErrorResponse(
    503,
    `Health check failed for ${component}`,
    requestId,
    { component, reason },
    'SERVICE_UNAVAILABLE'
  );
}

// Set up global error handlers
process.on('uncaughtException', error => {
  handleUncaughtError(error, 'uncaughtException');
  process.exit(1); // Exit on uncaught exception
});

process.on('unhandledRejection', (reason, promise) => {
  handleUncaughtError(new Error(reason), 'unhandledRejection');
});

module.exports = {
  // Error classes
  AppError,
  ValidationError,
  AuthenticationError,
  TOTPError,
  EncryptionError,
  StorageError,
  AIServiceError,
  CircuitBreaker,

  // Response creators
  createSuccessResponse,
  createErrorResponse,
  createRateLimitResponse,
  createValidationResponse,
  createHealthCheckError,

  // Error handlers
  handleError,
  handleUncaughtError,
  withErrorBoundary,
  withPerformanceMonitoring,

  // Error creators
  createConfigError,
  createTOTPError,
  createEncryptionError,
  createStorageError,
  createAIServiceError,

  // Utility functions
  asyncErrorHandler,
  retryWithBackoff,
  sanitizeErrorMessage,
  sanitizeErrorDetails,

  // Constants
  ERROR_CODES,
};
