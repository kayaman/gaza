/**
 * History Handler - Retrieves and decrypts conversation history
 * Handles TOTP validation and message decryption for history requests
 */

const { verifyTOTP } = require('../services/totp');
const { decryptMessage } = require('../services/encryption');
const { getConversationHistory, getSessionStats } = require('../services/storage');
const logger = require('../utils/logger');
const { createSuccessResponse, createErrorResponse } = require('../utils/errors');

/**
 * Handle history retrieval requests
 */
async function historyHandler(requestBody, context) {
  const { sessionId, totpCode, limit, includeStats } = requestBody;
  const requestId = context.awsRequestId;

  logger.info('Processing history request', {
    sessionId: sessionId.substring(0, 8) + '...',
    limit: limit || 'default',
    includeStats: !!includeStats,
    totpCode: totpCode ? 'present' : 'missing',
  });

  try {
    // Step 1: Verify TOTP code
    const totpSecret = process.env.TOTP_SECRET;
    if (!totpSecret) {
      logger.error('TOTP secret not configured');
      return createErrorResponse(500, 'Server configuration error', requestId);
    }

    const isValidTotp = verifyTOTP(totpCode, totpSecret);
    if (!isValidTotp) {
      logger.warn('TOTP validation failed for history request', {
        sessionId: sessionId.substring(0, 8) + '...',
        totpCode: totpCode ? 'provided' : 'missing',
        serverTime: new Date().toISOString(),
      });
      return createErrorResponse(401, 'Invalid or expired TOTP code', requestId);
    }

    logger.info('TOTP validation successful for history request');

    // Step 2: Retrieve encrypted conversation history
    const messageLimit = validateAndNormalizeLimit(limit);
    logger.info('Retrieving conversation history', {
      sessionId: sessionId.substring(0, 8) + '...',
      limit: messageLimit,
    });

    const encryptedHistory = await getConversationHistory(sessionId, messageLimit);

    if (encryptedHistory.length === 0) {
      logger.info('No conversation history found', {
        sessionId: sessionId.substring(0, 8) + '...',
      });

      const response = {
        success: true,
        history: [],
        sessionId: sessionId,
        messageCount: 0,
        timestamp: new Date().toISOString(),
      };

      // Include stats if requested
      if (includeStats) {
        response.stats = await getSessionStats(sessionId);
      }

      return createSuccessResponse(response, requestId);
    }

    // Step 3: Decrypt conversation history
    const decryptedHistory = [];
    const decryptionErrors = [];

    for (let i = 0; i < encryptedHistory.length; i++) {
      const msg = encryptedHistory[i];

      try {
        let decryptedContent;

        if (msg.content.startsWith('ENCRYPTED:')) {
          // Parse encrypted message format: ENCRYPTED:data:iv:totp
          const parts = msg.content.split(':');

          if (parts.length < 3) {
            logger.warn('Invalid encrypted message format', {
              messageIndex: i,
              role: msg.role,
              timestamp: msg.timestamp,
              partsCount: parts.length,
            });
            continue;
          }

          const msgEncrypted = parts[1];
          const msgIv = parts[2];
          const msgTotpCode = parts[3] || totpCode; // Use stored TOTP or current one

          // Try to decrypt with stored TOTP first, then current TOTP
          const totpCodesToTry = msgTotpCode ? [msgTotpCode, totpCode] : [totpCode];

          let decrypted = false;
          for (const tryTotpCode of totpCodesToTry) {
            try {
              decryptedContent = decryptMessage(msgEncrypted, msgIv, tryTotpCode);
              decrypted = true;
              break;
            } catch (decryptError) {
              // Continue to next TOTP code
            }
          }

          if (!decrypted) {
            logger.warn('Failed to decrypt message with available TOTP codes', {
              messageIndex: i,
              role: msg.role,
              timestamp: msg.timestamp,
              totpCodesAttempted: totpCodesToTry.length,
            });

            decryptionErrors.push({
              messageIndex: i,
              timestamp: msg.timestamp,
              role: msg.role,
              error: 'Unable to decrypt with available TOTP codes',
            });
            continue;
          }
        } else {
          // Handle unencrypted legacy messages
          decryptedContent = msg.content;
          logger.debug('Processing unencrypted legacy message', {
            messageIndex: i,
            role: msg.role,
            timestamp: msg.timestamp,
          });
        }

        decryptedHistory.push({
          role: msg.role,
          content: decryptedContent,
          timestamp: msg.timestamp,
          messageLength: decryptedContent.length,
        });
      } catch (decryptError) {
        logger.warn('Failed to decrypt history message', {
          error: decryptError.message,
          messageIndex: i,
          role: msg.role,
          timestamp: msg.timestamp,
        });

        decryptionErrors.push({
          messageIndex: i,
          timestamp: msg.timestamp,
          role: msg.role,
          error: decryptError.message,
        });
      }
    }

    logger.info('History decryption completed', {
      sessionId: sessionId.substring(0, 8) + '...',
      totalMessages: encryptedHistory.length,
      decryptedMessages: decryptedHistory.length,
      decryptionErrors: decryptionErrors.length,
    });

    // Step 4: Prepare response
    const response = {
      success: true,
      history: decryptedHistory,
      sessionId: sessionId,
      messageCount: decryptedHistory.length,
      totalMessages: encryptedHistory.length,
      timestamp: new Date().toISOString(),
    };

    // Include decryption errors if any (for debugging)
    if (decryptionErrors.length > 0) {
      response.decryptionErrors = decryptionErrors;
      response.warning = `${decryptionErrors.length} messages could not be decrypted`;
    }

    // Include session statistics if requested
    if (includeStats) {
      try {
        response.stats = await getSessionStats(sessionId);
      } catch (statsError) {
        logger.warn('Failed to retrieve session stats', {
          error: statsError.message,
          sessionId: sessionId.substring(0, 8) + '...',
        });
        response.statsError = 'Unable to retrieve session statistics';
      }
    }

    return createSuccessResponse(response, requestId);
  } catch (error) {
    logger.error('Unexpected error in history handler', {
      error: error.message,
      stack: error.stack,
      sessionId: sessionId.substring(0, 8) + '...',
    });

    return createErrorResponse(500, 'Internal server error', requestId);
  }
}

/**
 * Get paginated conversation history
 * @param {Object} requestBody - Request parameters
 * @param {Object} context - Lambda context
 * @returns {Promise<Object>} - Response object
 */
async function getPaginatedHistory(requestBody, context) {
  const { sessionId, totpCode, limit, offset, sortOrder } = requestBody;
  const requestId = context.awsRequestId;

  try {
    // Verify TOTP
    const totpSecret = process.env.TOTP_SECRET;
    const isValidTotp = verifyTOTP(totpCode, totpSecret);

    if (!isValidTotp) {
      return createErrorResponse(401, 'Invalid or expired TOTP code', requestId);
    }

    // Get all messages for the session (DynamoDB doesn't support offset directly)
    const allMessages = await getConversationHistory(sessionId, 1000);

    // Apply sorting
    const sortedMessages = sortOrder === 'desc' ? allMessages.reverse() : allMessages;

    // Apply pagination
    const startIndex = parseInt(offset) || 0;
    const pageSize = validateAndNormalizeLimit(limit);
    const paginatedMessages = sortedMessages.slice(startIndex, startIndex + pageSize);

    // Decrypt paginated messages
    const decryptedHistory = [];
    for (const msg of paginatedMessages) {
      try {
        let decryptedContent;

        if (msg.content.startsWith('ENCRYPTED:')) {
          const parts = msg.content.split(':');
          const msgEncrypted = parts[1];
          const msgIv = parts[2];
          const msgTotpCode = parts[3] || totpCode;

          decryptedContent = decryptMessage(msgEncrypted, msgIv, msgTotpCode);
        } else {
          decryptedContent = msg.content;
        }

        decryptedHistory.push({
          role: msg.role,
          content: decryptedContent,
          timestamp: msg.timestamp,
          messageLength: decryptedContent.length,
        });
      } catch (decryptError) {
        logger.warn('Failed to decrypt paginated message', {
          error: decryptError.message,
          timestamp: msg.timestamp,
        });
      }
    }

    const response = {
      success: true,
      history: decryptedHistory,
      pagination: {
        offset: startIndex,
        limit: pageSize,
        totalMessages: allMessages.length,
        hasMore: startIndex + pageSize < allMessages.length,
        nextOffset: startIndex + pageSize < allMessages.length ? startIndex + pageSize : null,
      },
      sessionId: sessionId,
      timestamp: new Date().toISOString(),
    };

    return createSuccessResponse(response, requestId);
  } catch (error) {
    logger.error('Error in paginated history handler', {
      error: error.message,
      sessionId: sessionId.substring(0, 8) + '...',
    });

    return createErrorResponse(500, 'Internal server error', requestId);
  }
}

/**
 * Search conversation history for specific content
 * @param {Object} requestBody - Request parameters
 * @param {Object} context - Lambda context
 * @returns {Promise<Object>} - Response object
 */
async function searchHistory(requestBody, context) {
  const { sessionId, totpCode, searchTerm, limit } = requestBody;
  const requestId = context.awsRequestId;

  try {
    // Verify TOTP
    const totpSecret = process.env.TOTP_SECRET;
    const isValidTotp = verifyTOTP(totpCode, totpSecret);

    if (!isValidTotp) {
      return createErrorResponse(401, 'Invalid or expired TOTP code', requestId);
    }

    if (!searchTerm || typeof searchTerm !== 'string' || searchTerm.trim().length === 0) {
      return createErrorResponse(400, 'Search term is required', requestId);
    }

    // Get all messages for the session
    const allMessages = await getConversationHistory(sessionId, 1000);
    const searchResults = [];

    for (let i = 0; i < allMessages.length; i++) {
      const msg = allMessages[i];

      try {
        let decryptedContent;

        if (msg.content.startsWith('ENCRYPTED:')) {
          const parts = msg.content.split(':');
          const msgEncrypted = parts[1];
          const msgIv = parts[2];
          const msgTotpCode = parts[3] || totpCode;

          decryptedContent = decryptMessage(msgEncrypted, msgIv, msgTotpCode);
        } else {
          decryptedContent = msg.content;
        }

        // Perform case-insensitive search
        if (decryptedContent.toLowerCase().includes(searchTerm.toLowerCase())) {
          searchResults.push({
            role: msg.role,
            content: decryptedContent,
            timestamp: msg.timestamp,
            messageIndex: i,
            messageLength: decryptedContent.length,
          });
        }

        // Limit search results
        if (searchResults.length >= (limit || 50)) {
          break;
        }
      } catch (decryptError) {
        logger.warn('Failed to decrypt message during search', {
          error: decryptError.message,
          messageIndex: i,
          timestamp: msg.timestamp,
        });
      }
    }

    const response = {
      success: true,
      searchResults,
      searchTerm,
      resultCount: searchResults.length,
      totalMessages: allMessages.length,
      sessionId: sessionId,
      timestamp: new Date().toISOString(),
    };

    return createSuccessResponse(response, requestId);
  } catch (error) {
    logger.error('Error in search history handler', {
      error: error.message,
      sessionId: sessionId.substring(0, 8) + '...',
      searchTerm: searchTerm?.substring(0, 20),
    });

    return createErrorResponse(500, 'Internal server error', requestId);
  }
}

/**
 * Validate and normalize the limit parameter
 * @param {any} limit - Limit value to validate
 * @returns {number} - Normalized limit value
 */
function validateAndNormalizeLimit(limit) {
  if (!limit) return 100; // Default limit

  const numericLimit = parseInt(limit);

  if (isNaN(numericLimit) || numericLimit < 1) {
    return 100; // Default limit
  }

  if (numericLimit > 1000) {
    return 1000; // Maximum limit
  }

  return numericLimit;
}

/**
 * Validate history request parameters
 * @param {Object} requestBody - Request body to validate
 * @returns {Object} - Validation result
 */
function validateHistoryRequest(requestBody) {
  const required = ['sessionId', 'totpCode'];
  const missing = required.filter(field => !requestBody[field]);

  if (missing.length > 0) {
    return {
      isValid: false,
      missingFields: missing,
    };
  }

  // Validate session ID format
  if (typeof requestBody.sessionId !== 'string' || requestBody.sessionId.length < 10) {
    return {
      isValid: false,
      error: 'Invalid session ID format',
    };
  }

  // Validate TOTP code format
  if (!/^\d{6}$/.test(requestBody.totpCode)) {
    return {
      isValid: false,
      error: 'Invalid TOTP code format',
    };
  }

  // Validate optional limit parameter
  if (requestBody.limit !== undefined) {
    const limit = parseInt(requestBody.limit);
    if (isNaN(limit) || limit < 1 || limit > 1000) {
      return {
        isValid: false,
        error: 'Limit must be a number between 1 and 1000',
      };
    }
  }

  return { isValid: true };
}

module.exports = {
  historyHandler,
  getPaginatedHistory,
  searchHistory,
  validateHistoryRequest,
};
