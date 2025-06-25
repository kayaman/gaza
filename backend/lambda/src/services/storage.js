/**
 * DynamoDB Storage Service
 * Handles encrypted conversation storage and retrieval
 */

const AWS = require('aws-sdk');
const logger = require('../utils/logger');

// DynamoDB configuration
const TABLE_NAME = process.env.DYNAMODB_TABLE || 'encrypted-chat-sessions';
const TTL_DAYS = parseInt(process.env.SESSION_TTL_DAYS) || 30;
const MAX_RETRY_ATTEMPTS = 3;
const BATCH_SIZE = 100;

// Initialize DynamoDB client
let dynamoDB;

/**
 * Initialize DynamoDB client with proper configuration
 */
function initializeDynamoDB() {
  if (dynamoDB) return dynamoDB;

  const config = {
    apiVersion: '2012-08-10',
    region: process.env.AWS_REGION || 'us-east-1',
  };

  // Use local DynamoDB endpoint if specified (for development)
  if (process.env.DYNAMODB_ENDPOINT) {
    config.endpoint = process.env.DYNAMODB_ENDPOINT;
    config.accessKeyId = process.env.DYNAMODB_ACCESS_KEY_ID || 'fakeAccessKeyId';
    config.secretAccessKey = process.env.DYNAMODB_SECRET_ACCESS_KEY || 'fakeSecretAccessKey';
  }

  dynamoDB = new AWS.DynamoDB.DocumentClient(config);

  logger.info('DynamoDB client initialized', {
    tableName: TABLE_NAME,
    region: config.region,
    endpoint: config.endpoint || 'default',
  });

  return dynamoDB;
}

/**
 * Store a message in the conversation history
 * @param {string} sessionId - Session identifier
 * @param {string} role - Message role ('user' or 'assistant')
 * @param {string} content - Message content (encrypted)
 * @returns {Promise<void>}
 */
async function storeMessage(sessionId, role, content) {
  const client = initializeDynamoDB();
  const timestamp = new Date().toISOString();
  const ttl = Math.floor(Date.now() / 1000) + TTL_DAYS * 24 * 60 * 60;

  try {
    // Validate inputs
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error('Session ID must be a non-empty string');
    }

    if (!['user', 'assistant'].includes(role)) {
      throw new Error('Role must be either "user" or "assistant"');
    }

    if (!content || typeof content !== 'string') {
      throw new Error('Content must be a non-empty string');
    }

    const item = {
      sessionId,
      timestamp,
      role,
      content,
      ttl,
      messageLength: content.length,
      createdAt: timestamp,
    };

    logger.debug('Storing message', {
      sessionId: sessionId.substring(0, 8) + '...',
      role,
      contentLength: content.length,
      ttlDays: TTL_DAYS,
    });

    const params = {
      TableName: TABLE_NAME,
      Item: item,
      // Prevent overwriting existing messages with same timestamp
      ConditionExpression: 'attribute_not_exists(sessionId) AND attribute_not_exists(#ts)',
      ExpressionAttributeNames: {
        '#ts': 'timestamp',
      },
    };

    await retryOperation(() => client.put(params).promise());

    logger.info('Message stored successfully', {
      sessionId: sessionId.substring(0, 8) + '...',
      role,
      timestamp,
    });
  } catch (error) {
    // Handle conditional check failures (duplicate timestamps)
    if (error.code === 'ConditionalCheckFailedException') {
      // Add microseconds to make timestamp unique
      const uniqueTimestamp = timestamp.replace('Z', `.${Date.now() % 1000}Z`);

      logger.warn('Timestamp collision detected, retrying with unique timestamp', {
        originalTimestamp: timestamp,
        uniqueTimestamp,
      });

      const retryItem = {
        sessionId,
        timestamp: uniqueTimestamp,
        role,
        content,
        ttl,
        messageLength: content.length,
        createdAt: timestamp,
      };

      const retryParams = {
        TableName: TABLE_NAME,
        Item: retryItem,
      };

      await retryOperation(() => client.put(retryParams).promise());
      return;
    }

    logger.error('Failed to store message', {
      error: error.message,
      sessionId: sessionId.substring(0, 8) + '...',
      role,
      errorCode: error.code,
    });

    throw new Error(`Failed to store message: ${error.message}`);
  }
}

/**
 * Retrieve conversation history for a session
 * @param {string} sessionId - Session identifier
 * @param {number} limit - Maximum number of messages to retrieve
 * @returns {Promise<Array>} - Array of messages
 */
async function getConversationHistory(sessionId, limit = 100) {
  const client = initializeDynamoDB();

  try {
    // Validate inputs
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error('Session ID must be a non-empty string');
    }

    if (limit && (typeof limit !== 'number' || limit < 1 || limit > 1000)) {
      throw new Error('Limit must be a number between 1 and 1000');
    }

    logger.debug('Retrieving conversation history', {
      sessionId: sessionId.substring(0, 8) + '...',
      limit,
    });

    const params = {
      TableName: TABLE_NAME,
      KeyConditionExpression: 'sessionId = :sessionId',
      ExpressionAttributeValues: {
        ':sessionId': sessionId,
      },
      ScanIndexForward: true, // Sort by timestamp ascending (oldest first)
      Limit: limit,
    };

    const result = await retryOperation(() => client.query(params).promise());

    const messages = result.Items || [];

    logger.info('Conversation history retrieved', {
      sessionId: sessionId.substring(0, 8) + '...',
      messageCount: messages.length,
      hasMore: !!result.LastEvaluatedKey,
    });

    return messages.map(item => ({
      role: item.role,
      content: item.content,
      timestamp: item.timestamp,
      messageLength: item.messageLength,
    }));
  } catch (error) {
    logger.error('Failed to retrieve conversation history', {
      error: error.message,
      sessionId: sessionId.substring(0, 8) + '...',
      errorCode: error.code,
    });

    // Return empty array instead of throwing to allow graceful degradation
    return [];
  }
}

/**
 * Delete conversation history for a session
 * @param {string} sessionId - Session identifier
 * @returns {Promise<number>} - Number of messages deleted
 */
async function deleteConversationHistory(sessionId) {
  const client = initializeDynamoDB();

  try {
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error('Session ID must be a non-empty string');
    }

    logger.info('Deleting conversation history', {
      sessionId: sessionId.substring(0, 8) + '...',
    });

    // First, get all messages for the session
    const messages = await getConversationHistory(sessionId, 1000);

    if (messages.length === 0) {
      logger.info('No messages found to delete', {
        sessionId: sessionId.substring(0, 8) + '...',
      });
      return 0;
    }

    // Delete messages in batches
    let deletedCount = 0;

    for (let i = 0; i < messages.length; i += BATCH_SIZE) {
      const batch = messages.slice(i, i + BATCH_SIZE);

      const deleteRequests = batch.map(message => ({
        DeleteRequest: {
          Key: {
            sessionId: sessionId,
            timestamp: message.timestamp,
          },
        },
      }));

      const batchParams = {
        RequestItems: {
          [TABLE_NAME]: deleteRequests,
        },
      };

      await retryOperation(() => client.batchWrite(batchParams).promise());
      deletedCount += batch.length;

      logger.debug('Batch deleted', {
        sessionId: sessionId.substring(0, 8) + '...',
        batchSize: batch.length,
        totalDeleted: deletedCount,
      });
    }

    logger.info('Conversation history deleted', {
      sessionId: sessionId.substring(0, 8) + '...',
      deletedCount,
    });

    return deletedCount;
  } catch (error) {
    logger.error('Failed to delete conversation history', {
      error: error.message,
      sessionId: sessionId.substring(0, 8) + '...',
      errorCode: error.code,
    });

    throw new Error(`Failed to delete conversation history: ${error.message}`);
  }
}

/**
 * Get session statistics
 * @param {string} sessionId - Session identifier
 * @returns {Promise<Object>} - Session statistics
 */
async function getSessionStats(sessionId) {
  const client = initializeDynamoDB();

  try {
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error('Session ID must be a non-empty string');
    }

    const params = {
      TableName: TABLE_NAME,
      KeyConditionExpression: 'sessionId = :sessionId',
      ExpressionAttributeValues: {
        ':sessionId': sessionId,
      },
      Select: 'COUNT',
    };

    const result = await retryOperation(() => client.query(params).promise());

    // Get detailed stats by retrieving all messages
    const messages = await getConversationHistory(sessionId, 1000);

    const userMessages = messages.filter(m => m.role === 'user');
    const assistantMessages = messages.filter(m => m.role === 'assistant');

    const totalContentLength = messages.reduce((sum, m) => sum + (m.messageLength || 0), 0);
    const averageMessageLength =
      messages.length > 0 ? Math.round(totalContentLength / messages.length) : 0;

    const firstMessage = messages.length > 0 ? messages[0] : null;
    const lastMessage = messages.length > 0 ? messages[messages.length - 1] : null;

    const stats = {
      sessionId: sessionId.substring(0, 8) + '...',
      totalMessages: messages.length,
      userMessages: userMessages.length,
      assistantMessages: assistantMessages.length,
      totalContentLength,
      averageMessageLength,
      firstMessageAt: firstMessage ? firstMessage.timestamp : null,
      lastMessageAt: lastMessage ? lastMessage.timestamp : null,
      sessionDuration:
        firstMessage && lastMessage
          ? new Date(lastMessage.timestamp).getTime() - new Date(firstMessage.timestamp).getTime()
          : 0,
    };

    logger.debug('Session stats calculated', stats);

    return stats;
  } catch (error) {
    logger.error('Failed to get session stats', {
      error: error.message,
      sessionId: sessionId.substring(0, 8) + '...',
    });

    return {
      sessionId: sessionId.substring(0, 8) + '...',
      totalMessages: 0,
      error: error.message,
    };
  }
}

/**
 * List all sessions (for admin/debugging purposes)
 * @param {number} limit - Maximum number of sessions to return
 * @returns {Promise<Array>} - Array of session information
 */
async function listSessions(limit = 50) {
  const client = initializeDynamoDB();

  try {
    logger.debug('Listing sessions', { limit });

    const params = {
      TableName: TABLE_NAME,
      Select: 'ALL_ATTRIBUTES',
      Limit: limit * 10, // Over-fetch to account for multiple messages per session
    };

    const result = await retryOperation(() => client.scan(params).promise());

    // Group messages by session
    const sessionMap = new Map();

    for (const item of result.Items || []) {
      const sessionId = item.sessionId;

      if (!sessionMap.has(sessionId)) {
        sessionMap.set(sessionId, {
          sessionId: sessionId.substring(0, 8) + '...',
          messageCount: 0,
          firstMessageAt: item.timestamp,
          lastMessageAt: item.timestamp,
          totalContentLength: 0,
        });
      }

      const session = sessionMap.get(sessionId);
      session.messageCount++;
      session.totalContentLength += item.messageLength || 0;

      if (item.timestamp < session.firstMessageAt) {
        session.firstMessageAt = item.timestamp;
      }

      if (item.timestamp > session.lastMessageAt) {
        session.lastMessageAt = item.timestamp;
      }
    }

    // Convert to array and sort by last message time
    const sessions = Array.from(sessionMap.values())
      .sort((a, b) => new Date(b.lastMessageAt) - new Date(a.lastMessageAt))
      .slice(0, limit);

    logger.info('Sessions listed', {
      totalSessions: sessions.length,
      scannedItems: result.Items ? result.Items.length : 0,
    });

    return sessions;
  } catch (error) {
    logger.error('Failed to list sessions', {
      error: error.message,
      errorCode: error.code,
    });

    return [];
  }
}

/**
 * Clean up expired sessions (manual cleanup for development)
 * @returns {Promise<number>} - Number of sessions cleaned up
 */
async function cleanupExpiredSessions() {
  const client = initializeDynamoDB();

  try {
    logger.info('Starting expired session cleanup');

    const cutoffTime = new Date(Date.now() - TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();

    const params = {
      TableName: TABLE_NAME,
      FilterExpression: '#ts < :cutoff',
      ExpressionAttributeNames: {
        '#ts': 'timestamp',
      },
      ExpressionAttributeValues: {
        ':cutoff': cutoffTime,
      },
    };

    const result = await retryOperation(() => client.scan(params).promise());
    const expiredItems = result.Items || [];

    if (expiredItems.length === 0) {
      logger.info('No expired sessions found');
      return 0;
    }

    // Delete expired items in batches
    let deletedCount = 0;

    for (let i = 0; i < expiredItems.length; i += BATCH_SIZE) {
      const batch = expiredItems.slice(i, i + BATCH_SIZE);

      const deleteRequests = batch.map(item => ({
        DeleteRequest: {
          Key: {
            sessionId: item.sessionId,
            timestamp: item.timestamp,
          },
        },
      }));

      const batchParams = {
        RequestItems: {
          [TABLE_NAME]: deleteRequests,
        },
      };

      await retryOperation(() => client.batchWrite(batchParams).promise());
      deletedCount += batch.length;
    }

    logger.info('Expired sessions cleaned up', {
      deletedCount,
      cutoffTime,
    });

    return deletedCount;
  } catch (error) {
    logger.error('Failed to cleanup expired sessions', {
      error: error.message,
      errorCode: error.code,
    });

    return 0;
  }
}

/**
 * Test DynamoDB connectivity and table access
 * @returns {Promise<Object>} - Test result
 */
async function testStorage() {
  const client = initializeDynamoDB();

  try {
    // Test table describe
    const describeParams = {
      TableName: TABLE_NAME,
    };

    const tableInfo = await retryOperation(() =>
      new AWS.DynamoDB({ region: client.options.region }).describeTable(describeParams).promise()
    );

    // Test write/read/delete cycle
    const testSessionId = `test-${Date.now()}`;
    const testContent = 'Test message for connectivity';

    await storeMessage(testSessionId, 'user', testContent);
    const history = await getConversationHistory(testSessionId);
    await deleteConversationHistory(testSessionId);

    const testPassed = history.length === 1 && history[0].content === testContent;

    return {
      success: testPassed,
      tableName: TABLE_NAME,
      tableStatus: tableInfo.Table.TableStatus,
      itemCount: tableInfo.Table.ItemCount,
      testSessionId,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    logger.error('Storage test failed', { error: error.message });

    return {
      success: false,
      error: error.message,
      tableName: TABLE_NAME,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Retry operation with exponential backoff
 * @param {Function} operation - Operation to retry
 * @param {number} maxAttempts - Maximum retry attempts
 * @returns {Promise} - Operation result
 */
async function retryOperation(operation, maxAttempts = MAX_RETRY_ATTEMPTS) {
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      // Don't retry on certain error types
      if (
        error.code === 'ValidationException' ||
        error.code === 'ConditionalCheckFailedException' ||
        error.code === 'ResourceNotFoundException'
      ) {
        throw error;
      }

      if (attempt < maxAttempts) {
        const delay = Math.pow(2, attempt - 1) * 1000; // Exponential backoff
        logger.warn(`DynamoDB operation failed, retrying in ${delay}ms`, {
          attempt,
          maxAttempts,
          error: error.message,
          errorCode: error.code,
        });
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError;
}

module.exports = {
  storeMessage,
  getConversationHistory,
  deleteConversationHistory,
  getSessionStats,
  listSessions,
  cleanupExpiredSessions,
  testStorage,

  // For testing and configuration
  TABLE_NAME,
  TTL_DAYS,
};
