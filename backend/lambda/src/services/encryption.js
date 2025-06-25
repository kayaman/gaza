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
