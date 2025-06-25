/**
 * Validator Utility - Comprehensive input validation and sanitization
 * Provides security-focused validation for all user inputs
 */

const logger = require('./logger');

/**
 * Validation rules and patterns
 */
const VALIDATION_PATTERNS = {
  // Basic patterns
  EMAIL: /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/,
  UUID: /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
  HEX: /^[0-9a-fA-F]+$/,
  BASE64: /^[A-Za-z0-9+/]*={0,2}$/,
  BASE32: /^[A-Z2-7]+=*$/,

  // Security patterns
  TOTP_CODE: /^\d{6}$/,
  SESSION_ID: /^[a-zA-Z0-9_-]{10,128}$/,

  // Content patterns
  SAFE_STRING: /^[a-zA-Z0-9\s\-_.,:;!?()[\]{}'"@#$%^&*+=~`|\\/<>]*$/,
  ALPHANUMERIC: /^[a-zA-Z0-9]+$/,
  NUMERIC: /^\d+$/,

  // Network patterns
  IP_ADDRESS:
    /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/,
  DOMAIN:
    /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/,

  // Dangerous patterns to reject
  SQL_INJECTION: /(\b(ALTER|CREATE|DELETE|DROP|EXEC(UTE)?|INSERT|SELECT|UNION|UPDATE)\b|[';--])/i,
  XSS_BASIC: /<script[^>]*>.*?<\/script>/gi,
  PATH_TRAVERSAL: /(\.\.[\/\\]|\.\.%2f|\.\.%5c)/i,
  COMMAND_INJECTION: /[;&|`$(){}[\]]/,
};

/**
 * Maximum lengths for different field types
 */
const MAX_LENGTHS = {
  SHORT_STRING: 100,
  MEDIUM_STRING: 500,
  LONG_STRING: 2000,
  MESSAGE_CONTENT: 100000, // ~100KB
  SESSION_ID: 128,
  TOTP_SECRET: 128,
  API_KEY: 200,
  ENCRYPTED_DATA: 200000, // ~200KB
  DOMAIN_NAME: 253,
  EMAIL: 254,
};

/**
 * Validate request body structure and required fields
 * @param {Object} body - Request body to validate
 * @param {Array} requiredFields - Array of required field names
 * @returns {Object} - Validation result
 */
function validateRequest(body, requiredFields = []) {
  logger.debug('Validating request', {
    requiredFields,
    providedFields: body ? Object.keys(body) : [],
  });

  if (!body || typeof body !== 'object') {
    return {
      isValid: false,
      errors: ['Request body must be an object'],
      missingFields: requiredFields,
    };
  }

  const errors = [];
  const missingFields = [];

  // Check for required fields
  for (const field of requiredFields) {
    if (!(field in body) || body[field] === null || body[field] === undefined) {
      missingFields.push(field);
      errors.push(`Missing required field: ${field}`);
    }
  }

  // Basic structure validation
  if (Object.keys(body).length > 50) {
    errors.push('Too many fields in request body');
  }

  const result = {
    isValid: errors.length === 0,
    errors,
    missingFields,
  };

  if (!result.isValid) {
    logger.warn('Request validation failed', {
      errors,
      missingFields,
      fieldCount: Object.keys(body).length,
    });
  }

  return result;
}

/**
 * Validate string field with specific requirements
 * @param {string} value - Value to validate
 * @param {Object} options - Validation options
 * @returns {Object} - Validation result
 */
function validateString(value, options = {}) {
  const {
    fieldName = 'field',
    required = true,
    minLength = 0,
    maxLength = MAX_LENGTHS.MEDIUM_STRING,
    pattern = null,
    allowEmpty = false,
    sanitize = true,
  } = options;

  const errors = [];

  // Check if value exists
  if (value === null || value === undefined) {
    if (required) {
      errors.push(`${fieldName} is required`);
    }
    return { isValid: !required, errors, sanitizedValue: null };
  }

  // Check type
  if (typeof value !== 'string') {
    errors.push(`${fieldName} must be a string`);
    return { isValid: false, errors, sanitizedValue: null };
  }

  // Check empty string
  if (value.length === 0 && !allowEmpty) {
    if (required) {
      errors.push(`${fieldName} cannot be empty`);
    }
    return { isValid: !required, errors, sanitizedValue: value };
  }

  // Check length
  if (value.length < minLength) {
    errors.push(`${fieldName} must be at least ${minLength} characters long`);
  }

  if (value.length > maxLength) {
    errors.push(`${fieldName} must be no more than ${maxLength} characters long`);
  }

  // Check pattern
  if (pattern && !pattern.test(value)) {
    errors.push(`${fieldName} format is invalid`);
  }

  // Security checks
  const securityIssues = checkSecurityPatterns(value, fieldName);
  errors.push(...securityIssues);

  // Sanitize if requested
  let sanitizedValue = value;
  if (sanitize && errors.length === 0) {
    sanitizedValue = sanitizeString(value);
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitizedValue,
  };
}

/**
 * Validate session ID format and security
 * @param {string} sessionId - Session ID to validate
 * @returns {Object} - Validation result
 */
function validateSessionId(sessionId) {
  return validateString(sessionId, {
    fieldName: 'sessionId',
    required: true,
    minLength: 10,
    maxLength: MAX_LENGTHS.SESSION_ID,
    pattern: VALIDATION_PATTERNS.SESSION_ID,
    sanitize: false,
  });
}

/**
 * Validate TOTP code format
 * @param {string} totpCode - TOTP code to validate
 * @returns {Object} - Validation result
 */
function validateTOTPCode(totpCode) {
  return validateString(totpCode, {
    fieldName: 'totpCode',
    required: true,
    minLength: 6,
    maxLength: 6,
    pattern: VALIDATION_PATTERNS.TOTP_CODE,
    sanitize: false,
  });
}

/**
 * Validate encrypted data format
 * @param {string} encryptedData - Encrypted data to validate
 * @returns {Object} - Validation result
 */
function validateEncryptedData(encryptedData) {
  return validateString(encryptedData, {
    fieldName: 'encryptedData',
    required: true,
    minLength: 32, // Minimum for salt + IV + tag + 1 byte data
    maxLength: MAX_LENGTHS.ENCRYPTED_DATA,
    pattern: VALIDATION_PATTERNS.HEX,
    sanitize: false,
  });
}

/**
 * Validate initialization vector format
 * @param {string} iv - IV to validate
 * @returns {Object} - Validation result
 */
function validateIV(iv) {
  return validateString(iv, {
    fieldName: 'iv',
    required: true,
    minLength: 24, // 12 bytes in hex
    maxLength: 32, // Allow some flexibility
    pattern: VALIDATION_PATTERNS.HEX,
    sanitize: false,
  });
}

/**
 * Validate message content
 * @param {string} content - Message content to validate
 * @returns {Object} - Validation result
 */
function validateMessageContent(content) {
  return validateString(content, {
    fieldName: 'content',
    required: true,
    minLength: 1,
    maxLength: MAX_LENGTHS.MESSAGE_CONTENT,
    pattern: null, // Allow any content for encrypted messages
    sanitize: true,
  });
}

/**
 * Validate numeric field
 * @param {any} value - Value to validate
 * @param {Object} options - Validation options
 * @returns {Object} - Validation result
 */
function validateNumber(value, options = {}) {
  const { fieldName = 'field', required = true, min = null, max = null, integer = false } = options;

  const errors = [];

  // Check if value exists
  if (value === null || value === undefined) {
    if (required) {
      errors.push(`${fieldName} is required`);
    }
    return { isValid: !required, errors, sanitizedValue: null };
  }

  // Convert to number
  const numValue = Number(value);

  // Check if valid number
  if (isNaN(numValue)) {
    errors.push(`${fieldName} must be a valid number`);
    return { isValid: false, errors, sanitizedValue: null };
  }

  // Check if integer is required
  if (integer && !Number.isInteger(numValue)) {
    errors.push(`${fieldName} must be an integer`);
  }

  // Check range
  if (min !== null && numValue < min) {
    errors.push(`${fieldName} must be at least ${min}`);
  }

  if (max !== null && numValue > max) {
    errors.push(`${fieldName} must be no more than ${max}`);
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitizedValue: numValue,
  };
}

/**
 * Validate boolean field
 * @param {any} value - Value to validate
 * @param {Object} options - Validation options
 * @returns {Object} - Validation result
 */
function validateBoolean(value, options = {}) {
  const { fieldName = 'field', required = true } = options;
  const errors = [];

  // Check if value exists
  if (value === null || value === undefined) {
    if (required) {
      errors.push(`${fieldName} is required`);
    }
    return { isValid: !required, errors, sanitizedValue: null };
  }

  // Convert to boolean
  let boolValue;
  if (typeof value === 'boolean') {
    boolValue = value;
  } else if (typeof value === 'string') {
    const lowerValue = value.toLowerCase();
    if (['true', '1', 'yes', 'on'].includes(lowerValue)) {
      boolValue = true;
    } else if (['false', '0', 'no', 'off'].includes(lowerValue)) {
      boolValue = false;
    } else {
      errors.push(`${fieldName} must be a valid boolean value`);
      return { isValid: false, errors, sanitizedValue: null };
    }
  } else {
    errors.push(`${fieldName} must be a boolean`);
    return { isValid: false, errors, sanitizedValue: null };
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitizedValue: boolValue,
  };
}

/**
 * Validate array field
 * @param {any} value - Value to validate
 * @param {Object} options - Validation options
 * @returns {Object} - Validation result
 */
function validateArray(value, options = {}) {
  const {
    fieldName = 'field',
    required = true,
    minLength = 0,
    maxLength = 100,
    itemValidator = null,
  } = options;

  const errors = [];

  // Check if value exists
  if (value === null || value === undefined) {
    if (required) {
      errors.push(`${fieldName} is required`);
    }
    return { isValid: !required, errors, sanitizedValue: null };
  }

  // Check if array
  if (!Array.isArray(value)) {
    errors.push(`${fieldName} must be an array`);
    return { isValid: false, errors, sanitizedValue: null };
  }

  // Check length
  if (value.length < minLength) {
    errors.push(`${fieldName} must have at least ${minLength} items`);
  }

  if (value.length > maxLength) {
    errors.push(`${fieldName} must have no more than ${maxLength} items`);
  }

  // Validate items if validator provided
  const sanitizedItems = [];
  if (itemValidator && errors.length === 0) {
    for (let i = 0; i < value.length; i++) {
      const itemResult = itemValidator(value[i], { fieldName: `${fieldName}[${i}]` });
      if (!itemResult.isValid) {
        errors.push(...itemResult.errors);
      } else {
        sanitizedItems.push(itemResult.sanitizedValue);
      }
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitizedValue: errors.length === 0 ? (itemValidator ? sanitizedItems : value) : null,
  };
}

/**
 * Check for security patterns in string values
 * @param {string} value - Value to check
 * @param {string} fieldName - Field name for error messages
 * @returns {Array} - Array of security issues
 */
function checkSecurityPatterns(value, fieldName) {
  const issues = [];

  // Check for SQL injection patterns
  if (VALIDATION_PATTERNS.SQL_INJECTION.test(value)) {
    issues.push(`${fieldName} contains potentially dangerous SQL patterns`);
  }

  // Check for XSS patterns
  if (VALIDATION_PATTERNS.XSS_BASIC.test(value)) {
    issues.push(`${fieldName} contains potentially dangerous script tags`);
  }

  // Check for path traversal
  if (VALIDATION_PATTERNS.PATH_TRAVERSAL.test(value)) {
    issues.push(`${fieldName} contains path traversal patterns`);
  }

  // Check for command injection
  if (VALIDATION_PATTERNS.COMMAND_INJECTION.test(value)) {
    issues.push(`${fieldName} contains command injection characters`);
  }

  // Check for excessively long strings (potential DoS)
  if (value.length > 1000000) {
    // 1MB
    issues.push(`${fieldName} is excessively long`);
  }

  return issues;
}

/**
 * Sanitize string value
 * @param {string} value - Value to sanitize
 * @returns {string} - Sanitized value
 */
function sanitizeString(value) {
  if (typeof value !== 'string') {
    return value;
  }

  return value
    .trim()
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '') // Remove control characters
    .replace(/\s+/g, ' '); // Normalize whitespace
}

/**
 * Validate email format
 * @param {string} email - Email to validate
 * @returns {Object} - Validation result
 */
function validateEmail(email) {
  return validateString(email, {
    fieldName: 'email',
    required: true,
    maxLength: MAX_LENGTHS.EMAIL,
    pattern: VALIDATION_PATTERNS.EMAIL,
    sanitize: true,
  });
}

/**
 * Validate UUID format
 * @param {string} uuid - UUID to validate
 * @returns {Object} - Validation result
 */
function validateUUID(uuid) {
  return validateString(uuid, {
    fieldName: 'uuid',
    required: true,
    minLength: 36,
    maxLength: 36,
    pattern: VALIDATION_PATTERNS.UUID,
    sanitize: false,
  });
}

/**
 * Validate domain name
 * @param {string} domain - Domain to validate
 * @returns {Object} - Validation result
 */
function validateDomain(domain) {
  return validateString(domain, {
    fieldName: 'domain',
    required: true,
    maxLength: MAX_LENGTHS.DOMAIN_NAME,
    pattern: VALIDATION_PATTERNS.DOMAIN,
    sanitize: true,
  });
}

/**
 * Validate IP address
 * @param {string} ip - IP address to validate
 * @returns {Object} - Validation result
 */
function validateIPAddress(ip) {
  return validateString(ip, {
    fieldName: 'ipAddress',
    required: true,
    maxLength: 15,
    pattern: VALIDATION_PATTERNS.IP_ADDRESS,
    sanitize: false,
  });
}

/**
 * Validate chat request structure
 * @param {Object} requestBody - Chat request to validate
 * @returns {Object} - Validation result
 */
function validateChatRequest(requestBody) {
  logger.debug('Validating chat request');

  // Check basic structure
  const basicValidation = validateRequest(requestBody, [
    'sessionId',
    'encryptedMessage',
    'iv',
    'totpCode',
  ]);
  if (!basicValidation.isValid) {
    return basicValidation;
  }

  const errors = [];
  const sanitizedData = {};

  // Validate each field
  const sessionIdResult = validateSessionId(requestBody.sessionId);
  if (!sessionIdResult.isValid) {
    errors.push(...sessionIdResult.errors);
  } else {
    sanitizedData.sessionId = sessionIdResult.sanitizedValue;
  }

  const totpResult = validateTOTPCode(requestBody.totpCode);
  if (!totpResult.isValid) {
    errors.push(...totpResult.errors);
  } else {
    sanitizedData.totpCode = totpResult.sanitizedValue;
  }

  const encryptedResult = validateEncryptedData(requestBody.encryptedMessage);
  if (!encryptedResult.isValid) {
    errors.push(...encryptedResult.errors);
  } else {
    sanitizedData.encryptedMessage = encryptedResult.sanitizedValue;
  }

  const ivResult = validateIV(requestBody.iv);
  if (!ivResult.isValid) {
    errors.push(...ivResult.errors);
  } else {
    sanitizedData.iv = ivResult.sanitizedValue;
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitizedData: errors.length === 0 ? sanitizedData : null,
  };
}

/**
 * Validate history request structure
 * @param {Object} requestBody - History request to validate
 * @returns {Object} - Validation result
 */
function validateHistoryRequest(requestBody) {
  logger.debug('Validating history request');

  // Check basic structure
  const basicValidation = validateRequest(requestBody, ['sessionId', 'totpCode']);
  if (!basicValidation.isValid) {
    return basicValidation;
  }

  const errors = [];
  const sanitizedData = {};

  // Validate required fields
  const sessionIdResult = validateSessionId(requestBody.sessionId);
  if (!sessionIdResult.isValid) {
    errors.push(...sessionIdResult.errors);
  } else {
    sanitizedData.sessionId = sessionIdResult.sanitizedValue;
  }

  const totpResult = validateTOTPCode(requestBody.totpCode);
  if (!totpResult.isValid) {
    errors.push(...totpResult.errors);
  } else {
    sanitizedData.totpCode = totpResult.sanitizedValue;
  }

  // Validate optional fields
  if (requestBody.limit !== undefined) {
    const limitResult = validateNumber(requestBody.limit, {
      fieldName: 'limit',
      required: false,
      min: 1,
      max: 1000,
      integer: true,
    });
    if (!limitResult.isValid) {
      errors.push(...limitResult.errors);
    } else {
      sanitizedData.limit = limitResult.sanitizedValue;
    }
  }

  if (requestBody.offset !== undefined) {
    const offsetResult = validateNumber(requestBody.offset, {
      fieldName: 'offset',
      required: false,
      min: 0,
      max: 100000,
      integer: true,
    });
    if (!offsetResult.isValid) {
      errors.push(...offsetResult.errors);
    } else {
      sanitizedData.offset = offsetResult.sanitizedValue;
    }
  }

  if (requestBody.includeStats !== undefined) {
    const statsResult = validateBoolean(requestBody.includeStats, {
      fieldName: 'includeStats',
      required: false,
    });
    if (!statsResult.isValid) {
      errors.push(...statsResult.errors);
    } else {
      sanitizedData.includeStats = statsResult.sanitizedValue;
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitizedData: errors.length === 0 ? sanitizedData : null,
  };
}

/**
 * Validate search request structure
 * @param {Object} requestBody - Search request to validate
 * @returns {Object} - Validation result
 */
function validateSearchRequest(requestBody) {
  logger.debug('Validating search request');

  // Check basic structure
  const basicValidation = validateRequest(requestBody, ['sessionId', 'totpCode', 'searchTerm']);
  if (!basicValidation.isValid) {
    return basicValidation;
  }

  const errors = [];
  const sanitizedData = {};

  // Validate required fields
  const sessionIdResult = validateSessionId(requestBody.sessionId);
  if (!sessionIdResult.isValid) {
    errors.push(...sessionIdResult.errors);
  } else {
    sanitizedData.sessionId = sessionIdResult.sanitizedValue;
  }

  const totpResult = validateTOTPCode(requestBody.totpCode);
  if (!totpResult.isValid) {
    errors.push(...totpResult.errors);
  } else {
    sanitizedData.totpCode = totpResult.sanitizedValue;
  }

  const searchTermResult = validateString(requestBody.searchTerm, {
    fieldName: 'searchTerm',
    required: true,
    minLength: 1,
    maxLength: 1000,
    sanitize: true,
  });
  if (!searchTermResult.isValid) {
    errors.push(...searchTermResult.errors);
  } else {
    sanitizedData.searchTerm = searchTermResult.sanitizedValue;
  }

  // Validate optional limit
  if (requestBody.limit !== undefined) {
    const limitResult = validateNumber(requestBody.limit, {
      fieldName: 'limit',
      required: false,
      min: 1,
      max: 100,
      integer: true,
    });
    if (!limitResult.isValid) {
      errors.push(...limitResult.errors);
    } else {
      sanitizedData.limit = limitResult.sanitizedValue;
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitizedData: errors.length === 0 ? sanitizedData : null,
  };
}

/**
 * Validate HTTP headers for security
 * @param {Object} headers - HTTP headers to validate
 * @returns {Object} - Validation result
 */
function validateHeaders(headers) {
  const errors = [];
  const warnings = [];

  if (!headers || typeof headers !== 'object') {
    return { isValid: true, errors: [], warnings: [] };
  }

  // Check for required security headers
  const securityHeaders = ['user-agent', 'content-type'];
  for (const header of securityHeaders) {
    if (!headers[header] && !headers[header.toLowerCase()]) {
      warnings.push(`Missing recommended header: ${header}`);
    }
  }

  // Check for suspicious headers
  const suspiciousPatterns = [
    /x-forwarded-for.*[;|&]/i,
    /user-agent.*(bot|crawler|spider)/i,
    /authorization.*bearer\s*$/i,
  ];

  for (const [headerName, headerValue] of Object.entries(headers)) {
    if (typeof headerValue === 'string') {
      for (const pattern of suspiciousPatterns) {
        if (pattern.test(`${headerName}:${headerValue}`)) {
          warnings.push(`Suspicious header pattern detected: ${headerName}`);
        }
      }

      // Check for excessively long headers
      if (headerValue.length > 8192) {
        errors.push(`Header ${headerName} is excessively long`);
      }
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Validate file upload (if applicable)
 * @param {Object} file - File object to validate
 * @param {Object} options - Validation options
 * @returns {Object} - Validation result
 */
function validateFile(file, options = {}) {
  const {
    maxSize = 10 * 1024 * 1024, // 10MB default
    allowedTypes = ['text/plain', 'application/json'],
    allowedExtensions = ['.txt', '.json'],
  } = options;

  const errors = [];

  if (!file) {
    errors.push('File is required');
    return { isValid: false, errors };
  }

  // Check file size
  if (file.size > maxSize) {
    errors.push(`File size exceeds maximum allowed size of ${maxSize} bytes`);
  }

  // Check file type
  if (file.type && !allowedTypes.includes(file.type)) {
    errors.push(`File type ${file.type} is not allowed`);
  }

  // Check file extension
  if (file.name) {
    const extension = file.name.toLowerCase().substring(file.name.lastIndexOf('.'));
    if (!allowedExtensions.includes(extension)) {
      errors.push(`File extension ${extension} is not allowed`);
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Rate limiting validation helper
 * @param {string} identifier - Unique identifier for rate limiting
 * @param {Object} options - Rate limiting options
 * @returns {Object} - Rate limit status
 */
function checkRateLimit(identifier, options = {}) {
  const {
    windowMs = 15 * 60 * 1000, // 15 minutes
    maxRequests = 100,
  } = options;

  // This is a simplified implementation
  // In production, use Redis or a proper rate limiting library

  if (!global.rateLimitStore) {
    global.rateLimitStore = new Map();
  }

  const now = Date.now();
  const windowStart = now - windowMs;

  // Clean old entries
  for (const [key, data] of global.rateLimitStore.entries()) {
    if (data.firstRequest < windowStart) {
      global.rateLimitStore.delete(key);
    }
  }

  // Check current identifier
  const currentData = global.rateLimitStore.get(identifier);

  if (!currentData) {
    global.rateLimitStore.set(identifier, {
      firstRequest: now,
      requestCount: 1,
    });
    return {
      allowed: true,
      remaining: maxRequests - 1,
      resetTime: now + windowMs,
    };
  }

  if (currentData.firstRequest < windowStart) {
    // Reset window
    global.rateLimitStore.set(identifier, {
      firstRequest: now,
      requestCount: 1,
    });
    return {
      allowed: true,
      remaining: maxRequests - 1,
      resetTime: now + windowMs,
    };
  }

  // Check if limit exceeded
  if (currentData.requestCount >= maxRequests) {
    return {
      allowed: false,
      remaining: 0,
      resetTime: currentData.firstRequest + windowMs,
      retryAfter: currentData.firstRequest + windowMs - now,
    };
  }

  // Increment counter
  currentData.requestCount++;

  return {
    allowed: true,
    remaining: maxRequests - currentData.requestCount,
    resetTime: currentData.firstRequest + windowMs,
  };
}

module.exports = {
  validateRequest,
  validateString,
  validateNumber,
  validateBoolean,
  validateArray,
  validateSessionId,
  validateTOTPCode,
  validateEncryptedData,
  validateIV,
  validateMessageContent,
  validateEmail,
  validateUUID,
  validateDomain,
  validateIPAddress,
  validateChatRequest,
  validateHistoryRequest,
  validateSearchRequest,
  validateHeaders,
  validateFile,
  checkRateLimit,
  sanitizeString,
  checkSecurityPatterns,

  // Export constants for external use
  VALIDATION_PATTERNS,
  MAX_LENGTHS,
};
