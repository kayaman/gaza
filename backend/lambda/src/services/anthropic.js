/**
 * Anthropic API Service
 * Handles communication with Claude API
 */

const https = require('https');
const logger = require('../utils/logger');

// Anthropic API configuration
const ANTHROPIC_API_URL = 'api.anthropic.com';
const API_VERSION = '2023-06-01';
const DEFAULT_MODEL = 'claude-3-sonnet-20240229';
const DEFAULT_MAX_TOKENS = 4000;
const REQUEST_TIMEOUT = 60000; // 60 seconds
const MAX_RETRIES = 3;
const RETRY_DELAY = 1000; // 1 second

/**
 * Call Anthropic Claude API with conversation messages
 * @param {Array} messages - Array of message objects {role, content}
 * @param {Object} options - Optional parameters
 * @returns {Promise<string>} - Claude's response content
 */
async function callAnthropicAPI(messages, options = {}) {
  const startTime = Date.now();

  try {
    // Validate inputs
    if (!Array.isArray(messages) || messages.length === 0) {
      throw new Error('Messages must be a non-empty array');
    }

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      throw new Error('ANTHROPIC_API_KEY environment variable is not set');
    }

    // Validate message format
    validateMessages(messages);

    // Prepare request payload
    const payload = {
      model: options.model || DEFAULT_MODEL,
      max_tokens: options.maxTokens || DEFAULT_MAX_TOKENS,
      messages: messages.map(msg => ({
        role: msg.role,
        content: msg.content,
      })),
      temperature: options.temperature || 0.7,
      top_p: options.topP || 0.9,
      stop_sequences: options.stopSequences || [],
    };

    // Add system message if provided
    if (options.systemMessage) {
      payload.system = options.systemMessage;
    }

    logger.info('Calling Anthropic API', {
      model: payload.model,
      messageCount: messages.length,
      maxTokens: payload.max_tokens,
      totalInputLength: messages.reduce((sum, msg) => sum + msg.content.length, 0),
    });

    // Make API call with retry logic
    const response = await makeAPICallWithRetry(payload, apiKey);

    const duration = Date.now() - startTime;
    logger.info('Anthropic API call completed', {
      duration,
      responseLength: response.length,
      model: payload.model,
    });

    return response;
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error('Anthropic API call failed', {
      error: error.message,
      duration,
      messageCount: messages.length,
    });
    throw error;
  }
}

/**
 * Make HTTP request to Anthropic API with retry logic
 * @param {Object} payload - Request payload
 * @param {string} apiKey - Anthropic API key
 * @returns {Promise<string>} - Response content
 */
async function makeAPICallWithRetry(payload, apiKey) {
  let lastError;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      logger.debug(`Anthropic API attempt ${attempt}/${MAX_RETRIES}`);

      const response = await makeHTTPRequest(payload, apiKey);
      return response;
    } catch (error) {
      lastError = error;

      // Don't retry on client errors (4xx)
      if (error.statusCode && error.statusCode >= 400 && error.statusCode < 500) {
        logger.error('Client error, not retrying', {
          statusCode: error.statusCode,
          error: error.message,
        });
        throw error;
      }

      // Retry on server errors (5xx) and network errors
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_DELAY * Math.pow(2, attempt - 1); // Exponential backoff
        logger.warn(`API call failed, retrying in ${delay}ms`, {
          attempt,
          error: error.message,
          statusCode: error.statusCode,
        });
        await sleep(delay);
      }
    }
  }

  throw lastError;
}

/**
 * Make HTTP request to Anthropic API
 * @param {Object} payload - Request payload
 * @param {string} apiKey - Anthropic API key
 * @returns {Promise<string>} - Response content
 */
function makeHTTPRequest(payload, apiKey) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(payload);

    const options = {
      hostname: ANTHROPIC_API_URL,
      port: 443,
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        'x-api-key': apiKey,
        'anthropic-version': API_VERSION,
        'User-Agent': 'secure-ai-chat-proxy/1.0',
      },
      timeout: REQUEST_TIMEOUT,
    };

    const req = https.request(options, res => {
      let responseData = '';

      res.on('data', chunk => {
        responseData += chunk;
      });

      res.on('end', () => {
        try {
          logger.debug('Anthropic API response received', {
            statusCode: res.statusCode,
            responseLength: responseData.length,
            headers: Object.keys(res.headers),
          });

          if (res.statusCode !== 200) {
            const error = new Error(`Anthropic API error: ${res.statusCode} ${res.statusMessage}`);
            error.statusCode = res.statusCode;
            error.response = responseData;
            reject(error);
            return;
          }

          const response = JSON.parse(responseData);

          // Validate response format
          if (
            !response.content ||
            !Array.isArray(response.content) ||
            response.content.length === 0
          ) {
            reject(new Error('Invalid response format from Anthropic API'));
            return;
          }

          const textContent = response.content
            .filter(item => item.type === 'text')
            .map(item => item.text)
            .join('');

          if (!textContent) {
            reject(new Error('No text content in Anthropic API response'));
            return;
          }

          resolve(textContent);
        } catch (parseError) {
          logger.error('Failed to parse Anthropic API response', {
            error: parseError.message,
            responseData: responseData.substring(0, 500),
          });
          reject(new Error('Failed to parse Anthropic API response'));
        }
      });
    });

    req.on('error', error => {
      logger.error('HTTP request error', { error: error.message });
      reject(new Error(`Network error: ${error.message}`));
    });

    req.on('timeout', () => {
      logger.error('Anthropic API request timeout');
      req.destroy();
      reject(new Error('Request timeout'));
    });

    // Write request data
    req.write(data);
    req.end();
  });
}

/**
 * Validate message format for Anthropic API
 * @param {Array} messages - Messages to validate
 */
function validateMessages(messages) {
  for (let i = 0; i < messages.length; i++) {
    const message = messages[i];

    if (!message || typeof message !== 'object') {
      throw new Error(`Message ${i} must be an object`);
    }

    if (!message.role || typeof message.role !== 'string') {
      throw new Error(`Message ${i} must have a valid role`);
    }

    if (!['user', 'assistant'].includes(message.role)) {
      throw new Error(`Message ${i} role must be 'user' or 'assistant'`);
    }

    if (!message.content || typeof message.content !== 'string') {
      throw new Error(`Message ${i} must have valid content`);
    }

    if (message.content.length === 0) {
      throw new Error(`Message ${i} content cannot be empty`);
    }

    if (message.content.length > 200000) {
      // ~200KB limit
      throw new Error(`Message ${i} content too long (max 200KB)`);
    }
  }

  // Validate conversation flow
  if (messages[messages.length - 1].role !== 'user') {
    throw new Error('Last message must be from user');
  }

  // Check for alternating roles (recommended pattern)
  for (let i = 1; i < messages.length; i++) {
    const prevRole = messages[i - 1].role;
    const currentRole = messages[i].role;

    if (prevRole === currentRole && currentRole === 'user') {
      logger.warn('Multiple consecutive user messages detected', { messageIndex: i });
    }
  }
}

/**
 * Format conversation history for Anthropic API
 * @param {Array} rawMessages - Raw message history
 * @returns {Array} - Formatted messages
 */
function formatConversationHistory(rawMessages) {
  return rawMessages
    .filter(msg => msg.content && msg.content.trim().length > 0)
    .map(msg => ({
      role: msg.role === 'assistant' ? 'assistant' : 'user',
      content: msg.content.trim(),
    }));
}

/**
 * Count tokens in text (approximate)
 * @param {string} text - Text to count tokens for
 * @returns {number} - Approximate token count
 */
function estimateTokenCount(text) {
  // Rough estimation: ~4 characters per token for English text
  return Math.ceil(text.length / 4);
}

/**
 * Check if conversation is within token limits
 * @param {Array} messages - Conversation messages
 * @param {number} maxTokens - Maximum token limit
 * @returns {Object} - Token usage info
 */
function checkTokenLimits(messages, maxTokens = 100000) {
  const totalText = messages.map(msg => msg.content).join(' ');
  const estimatedTokens = estimateTokenCount(totalText);

  return {
    estimatedTokens,
    maxTokens,
    isWithinLimit: estimatedTokens <= maxTokens,
    utilizationPercent: Math.round((estimatedTokens / maxTokens) * 100),
  };
}

/**
 * Truncate conversation to fit within token limits
 * @param {Array} messages - Conversation messages
 * @param {number} maxTokens - Maximum token limit
 * @returns {Array} - Truncated messages
 */
function truncateConversation(messages, maxTokens = 80000) {
  if (messages.length <= 1) return messages;

  // Always keep the last message (current user input)
  const lastMessage = messages[messages.length - 1];
  const otherMessages = messages.slice(0, -1);

  let tokenCount = estimateTokenCount(lastMessage.content);
  const truncatedMessages = [];

  // Add messages from most recent to oldest until we hit the limit
  for (let i = otherMessages.length - 1; i >= 0; i--) {
    const messageTokens = estimateTokenCount(otherMessages[i].content);

    if (tokenCount + messageTokens <= maxTokens) {
      truncatedMessages.unshift(otherMessages[i]);
      tokenCount += messageTokens;
    } else {
      break;
    }
  }

  truncatedMessages.push(lastMessage);

  logger.info('Conversation truncated', {
    originalLength: messages.length,
    truncatedLength: truncatedMessages.length,
    estimatedTokens: tokenCount,
  });

  return truncatedMessages;
}

/**
 * Test Anthropic API connectivity
 * @returns {Promise<Object>} - Test result
 */
async function testAnthropicAPI() {
  try {
    const testMessages = [
      {
        role: 'user',
        content: 'Hello! Please respond with just "OK" to confirm the connection is working.',
      },
    ];

    const response = await callAnthropicAPI(testMessages, { maxTokens: 10 });

    return {
      success: true,
      response: response.substring(0, 100),
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Sleep utility function
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise} - Promise that resolves after delay
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = {
  callAnthropicAPI,
  validateMessages,
  formatConversationHistory,
  estimateTokenCount,
  checkTokenLimits,
  truncateConversation,
  testAnthropicAPI,

  // Constants for external use
  DEFAULT_MODEL,
  DEFAULT_MAX_TOKENS,
  API_VERSION,
};
