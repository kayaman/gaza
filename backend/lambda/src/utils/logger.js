/**
 * Logger Utility - Comprehensive logging with context and security
 * Provides structured logging with request correlation and security filtering
 */

// Log levels
const LOG_LEVELS = {
    ERROR: 0,
    WARN: 1,
    INFO: 2,
    DEBUG: 3,
    TRACE: 4
};

// Current log level from environment
const CURRENT_LOG_LEVEL = LOG_LEVELS[process.env.LOG_LEVEL?.toUpperCase()] ?? LOG_LEVELS.INFO;

// Request context storage
let requestContext = {};

/**
 * Logger class with contextual information
 */
class Logger {
    constructor() {
        this.context = {};
    }

    /**
     * Set request context for correlation
     * @param {Object} context - Request context
     */
    setContext(context) {
        requestContext = {
            ...requestContext,
            ...context,
            timestamp: new Date().toISOString()
        };
    }

    /**
     * Get current context
     * @returns {Object} - Current context
     */
    getContext() {
        return { ...requestContext };
    }

    /**
     * Clear request context
     */
    clearContext() {
        requestContext = {};
    }

    /**
     * Create log entry with metadata
     * @param {string} level - Log level
     * @param {string} message - Log message
     * @param {Object} data - Additional data
     * @param {Error} error - Error object (optional)
     */
    log(level, message, data = {}, error = null) {
        const levelNum = LOG_LEVELS[level.toUpperCase()];
        
        // Skip if below current log level
        if (levelNum > CURRENT_LOG_LEVEL) {
            return;
        }

        const logEntry = {
            timestamp: new Date().toISOString(),
            level: level.toUpperCase(),
            message: this.sanitizeMessage(message),
            ...this.sanitizeData(data),
            ...this.getMetadata(),
            ...requestContext
        };

        // Add error details if provided
        if (error) {
            logEntry.error = {
                message: error.message,
                name: error.name,
                stack: error.stack,
                code: error.code
            };
        }

        // Add AWS Lambda context if available
        if (process.env.AWS_LAMBDA_FUNCTION_NAME) {
            logEntry.lambda = {
                functionName: process.env.AWS_LAMBDA_FUNCTION_NAME,
                functionVersion: process.env.AWS_LAMBDA_FUNCTION_VERSION,
                logGroupName: process.env.AWS_LAMBDA_LOG_GROUP_NAME,
                logStreamName: process.env.AWS_LAMBDA_LOG_STREAM_NAME
            };
        }

        // Output based on environment
        if (process.env.NODE_ENV === 'production' || process.env.LOG_FORMAT === 'json') {
            console.log(JSON.stringify(logEntry));
        } else {
            // Pretty print for development
            const coloredLevel = this.colorizeLevel(level);
            const timestamp = logEntry.timestamp.split('T')[1].slice(0, -1); // Just time part
            
            console.log(`${timestamp} ${coloredLevel} ${message}`);
            
            if (Object.keys(data).length > 0) {
                console.log('  Data:', JSON.stringify(this.sanitizeData(data), null, 2));
            }
            
            if (error) {
                console.log('  Error:', error.message);
                if (CURRENT_LOG_LEVEL >= LOG_LEVELS.DEBUG) {
                    console.log('  Stack:', error.stack);
                }
            }
        }
    }

    /**
     * Error level logging
     * @param {string} message - Log message
     * @param {Object} data - Additional data
     * @param {Error} error - Error object
     */
    error(message, data = {}, error = null) {
        this.log('ERROR', message, data, error);
    }

    /**
     * Warning level logging
     * @param {string} message - Log message
     * @param {Object} data - Additional data
     */
    warn(message, data = {}) {
        this.log('WARN', message, data);
    }

    /**
     * Info level logging
     * @param {string} message - Log message
     * @param {Object} data - Additional data
     */
    info(message, data = {}) {
        this.log('INFO', message, data);
    }

    /**
     * Debug level logging
     * @param {string} message - Log message
     * @param {Object} data - Additional data
     */
    debug(message, data = {}) {
        this.log('DEBUG', message, data);
    }

    /**
     * Trace level logging
     * @param {string} message - Log message
     * @param {Object} data - Additional data
     */
    trace(message, data = {}) {
        this.log('TRACE', message, data);
    }

    /**
     * Performance timing helper
     * @param {string} operation - Operation name
     * @returns {Function} - End timing function
     */
    startTimer(operation) {
        const startTime = Date.now();
        const startHrTime = process.hrtime.bigint();
        
        return (data = {}) => {
            const duration = Date.now() - startTime;
            const precisionDuration = Number(process.hrtime.bigint() - startHrTime) / 1000000; // nanoseconds to milliseconds
            
            this.info(`${operation} completed`, {
                ...data,
                operation,
                duration,
                precisionDuration: Math.round(precisionDuration * 100) / 100 // 2 decimal places
            });
            
            return { duration, precisionDuration };
        };
    }

    /**
     * Request logging helper
     * @param {string} method - HTTP method
     * @param {string} path - Request path
     * @param {Object} metadata - Request metadata
     */
    request(method, path, metadata = {}) {
        this.info('Request received', {
            httpMethod: method,
            path,
            ...this.sanitizeData(metadata)
        });
    }

    /**
     * Response logging helper
     * @param {number} statusCode - HTTP status code
     * @param {number} duration - Request duration
     * @param {Object} metadata - Response metadata
     */
    response(statusCode, duration, metadata = {}) {
        const level = statusCode >= 400 ? 'warn' : 'info';
        
        this[level]('Request completed', {
            statusCode,
            duration,
            success: statusCode < 400,
            ...this.sanitizeData(metadata)
        });
    }

    /**
     * Database operation logging
     * @param {string} operation - Database operation
     * @param {string} table - Table name
     * @param {Object} metadata - Operation metadata
     */
    database(operation, table, metadata = {}) {
        this.debug('Database operation', {
            operation,
            table: table || 'unknown',
            ...this.sanitizeData(metadata)
        });
    }

    /**
     * API call logging
     * @param {string} service - External service name
     * @param {string} method - HTTP method
     * @param {string} endpoint - API endpoint
     * @param {Object} metadata - Call metadata
     */
    apiCall(service, method, endpoint, metadata = {}) {
        this.info('External API call', {
            service,
            method,
            endpoint,
            ...this.sanitizeData(metadata)
        });
    }

    /**
     * Security event logging
     * @param {string} event - Security event type
     * @param {Object} details - Event details
     */
    security(event, details = {}) {
        this.warn('Security event', {
            securityEvent: event,
            ...this.sanitizeData(details)
        });
    }

    /**
     * Business metric logging
     * @param {string} metric - Metric name
     * @param {number} value - Metric value
     * @param {Object} dimensions - Metric dimensions
     */
    metric(metric, value, dimensions = {}) {
        this.info('Business metric', {
            metric,
            value,
            dimensions: this.sanitizeData(dimensions),
            metricType: 'business'
        });
    }

    /**
     * Sanitize log message to remove sensitive information
     * @param {string} message - Log message
     * @returns {string} - Sanitized message
     */
    sanitizeMessage(message) {
        if (typeof message !== 'string') {
            return String(message);
        }

        // Remove common sensitive patterns
        return message
            .replace(/api[_-]?key[=:]\s*[^\s,}]+/gi, 'api_key=***')
            .replace(/password[=:]\s*[^\s,}]+/gi, 'password=***')
            .replace(/token[=:]\s*[^\s,}]+/gi, 'token=***')
            .replace(/secret[=:]\s*[^\s,}]+/gi, 'secret=***')
            .replace(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, '***@***.***');
    }

    /**
     * Sanitize data object to remove sensitive information
     * @param {Object} data - Data object
     * @returns {Object} - Sanitized data
     */
    sanitizeData(data) {
        if (!data || typeof data !== 'object') {
            return data;
        }

        const sensitiveKeys = [
            'password', 'token', 'secret', 'key', 'auth', 'authorization',
            'apikey', 'api_key', 'anthropic_api_key', 'totp_secret',
            'sessiontoken', 'accesstoken', 'refreshtoken'
        ];

        const sanitized = {};
        
        for (const [key, value] of Object.entries(data)) {
            const lowerKey = key.toLowerCase();
            
            if (sensitiveKeys.some(sensitive => lowerKey.includes(sensitive))) {
                if (typeof value === 'string' && value.length > 0) {
                    sanitized[key] = this.maskValue(value);
                } else {
                    sanitized[key] = '***';
                }
            } else if (Array.isArray(value)) {
                sanitized[key] = value.map(item => 
                    typeof item === 'object' ? this.sanitizeData(item) : item
                );
            } else if (value && typeof value === 'object') {
                sanitized[key] = this.sanitizeData(value);
            } else {
                sanitized[key] = value;
            }
        }
        
        return sanitized;
    }

    /**
     * Mask sensitive values
     * @param {string} value - Value to mask
     * @returns {string} - Masked value
     */
    maskValue(value) {
        if (!value || typeof value !== 'string') {
            return '***';
        }
        
        if (value.length <= 8) {
            return '***';
        }
        
        const start = value.substring(0, 3);
        const end = value.substring(value.length - 3);
        const middle = '*'.repeat(Math.min(value.length - 6, 10));
        
        return `${start}${middle}${end}`;
    }

    /**
     * Get system metadata
     * @returns {Object} - System metadata
     */
    getMetadata() {
        return {
            nodeVersion: process.version,
            platform: process.platform,
            arch: process.arch,
            pid: process.pid,
            memoryUsage: this.getMemoryUsage(),
            environment: process.env.NODE_ENV || 'unknown'
        };
    }

    /**
     * Get memory usage information
     * @returns {Object} - Memory usage
     */
    getMemoryUsage() {
        const usage = process.memoryUsage();
        return {
            rss: Math.round(usage.rss / 1024 / 1024), // MB
            heapUsed: Math.round(usage.heapUsed / 1024 / 1024), // MB
            heapTotal: Math.round(usage.heapTotal / 1024 / 1024), // MB
            external: Math.round(usage.external / 1024 / 1024) // MB
        };
    }

    /**
     * Colorize log level for console output
     * @param {string} level - Log level
     * @returns {string} - Colorized level
     */
    colorizeLevel(level) {
        const colors = {
            ERROR: '\x1b[31m', // Red
            WARN: '\x1b[33m',  // Yellow
            INFO: '\x1b[36m',  // Cyan
            DEBUG: '\x1b[35m', // Magenta
            TRACE: '\x1b[37m'  // White
        };
        
        const reset = '\x1b[0m';
        const color = colors[level.toUpperCase()] || colors.INFO;
        
        return `${color}${level.toUpperCase()}${reset}`;
    }

    /**
     * Create a child logger with additional context
     * @param {Object} additionalContext - Additional context
     * @returns {Logger} - Child logger
     */
    child(additionalContext) {
        const childLogger = new Logger();
        childLogger.context = {
            ...this.context,
            ...additionalContext
        };
        return childLogger;
    }

    /**
     * Log function entry for debugging
     * @param {string} functionName - Function name
     * @param {Object} args - Function arguments (sanitized)
     */
    enter(functionName, args = {}) {
        this.trace(`Entering ${functionName}`, {
            function: functionName,
            args: this.sanitizeData(args)
        });
    }

    /**
     * Log function exit for debugging
     * @param {string} functionName - Function name
     * @param {any} result - Function result (sanitized)
     */
    exit(functionName, result = null) {
        this.trace(`Exiting ${functionName}`, {
            function: functionName,
            result: result ? this.sanitizeData({ result }).result : null
        });
    }
}

// Create singleton instance
const logger = new Logger();

// Export both the instance and the class
module.exports = logger;
module.exports.Logger = Logger;
module.exports.LOG_LEVELS = LOG_LEVELS;