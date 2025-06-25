// AWS Lambda Handler for Encrypted Chat Proxy
const AWS = require('aws-sdk');
const https = require('https');
const crypto = require('crypto');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const TABLE_NAME = 'encrypted-chat-sessions';

exports.handler = async event => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Content-Type': 'application/json',
  };

  // Handle preflight OPTIONS request
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: '',
    };
  }

  try {
    const body = JSON.parse(event.body);
    const { action, sessionId, encryptedMessage, iv, totpCode } = body;

    if (action === 'chat') {
      return await handleChat(sessionId, encryptedMessage, iv, totpCode, headers);
    } else if (action === 'getHistory') {
      return await getHistory(sessionId, totpCode, headers);
    } else {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'Invalid action' }),
      };
    }
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};

async function handleChat(sessionId, encryptedMessage, iv, totpCode, headers) {
  try {
    // Verify TOTP and derive encryption key
    const isValidTotp = verifyTOTP(totpCode, process.env.TOTP_SECRET);
    if (!isValidTotp) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: 'Invalid TOTP code' }),
      };
    }

    // Use TOTP as encryption key
    const encryptionKey = totpCode;

    // Decrypt the incoming message
    const decryptedMessage = decryptMessage(encryptedMessage, iv, encryptionKey);

    // Get conversation history and decrypt it
    const encryptedHistory = await getConversationHistory(sessionId);
    const decryptedHistory = encryptedHistory.map(msg => {
      if (msg.content.startsWith('ENCRYPTED:')) {
        const parts = msg.content.split(':');
        const msgEncrypted = parts[1];
        const msgIv = parts[2];
        return {
          role: msg.role,
          content: decryptMessage(msgEncrypted, msgIv, encryptionKey),
        };
      }
      return msg;
    });

    // Prepare messages for Anthropic API (fully decrypted)
    const messages = [
      ...decryptedHistory,
      {
        role: 'user',
        content: decryptedMessage,
      },
    ];

    // Call Anthropic API with clear text
    const anthropicResponse = await callAnthropicAPI(messages);

    // Encrypt response for storage and transmission
    const encryptedResponse = encryptMessage(anthropicResponse, encryptionKey);

    // Store the conversation (encrypted)
    await storeMessage(sessionId, 'user', `ENCRYPTED:${encryptedMessage}:${iv}`);
    await storeMessage(
      sessionId,
      'assistant',
      `ENCRYPTED:${encryptedResponse.encrypted}:${encryptedResponse.iv}`
    );

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        encryptedResponse: encryptedResponse.encrypted,
        responseIv: encryptedResponse.iv,
        totpUsed: encryptionKey, // Return the TOTP that was used for encryption
        sessionId: sessionId,
      }),
    };
  } catch (error) {
    console.error('Chat error:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Chat processing failed: ' + error.message }),
    };
  }
}

async function callAnthropicAPI(messages) {
  const payload = {
    model: 'claude-3-sonnet-20240229',
    max_tokens: 4000,
    messages: messages, // Now contains decrypted, readable messages
  };

  return new Promise((resolve, reject) => {
    const data = JSON.stringify(payload);

    const options = {
      hostname: 'api.anthropic.com',
      port: 443,
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Length': data.length,
      },
    };

    const req = https.request(options, res => {
      let responseData = '';

      res.on('data', chunk => {
        responseData += chunk;
      });

      res.on('end', () => {
        try {
          const response = JSON.parse(responseData);
          if (response.content && response.content[0]) {
            resolve(response.content[0].text);
          } else {
            reject(new Error('Invalid response format'));
          }
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// TOTP verification function
function verifyTOTP(token, secret) {
  const crypto = require('crypto');
  const window = 1; // Allow 1 time step before/after current

  const timeStep = 30; // 30 seconds
  const currentTime = Math.floor(Date.now() / 1000 / timeStep);

  for (let i = -window; i <= window; i++) {
    const timeSlice = currentTime + i;
    const expectedToken = generateTOTP(secret, timeSlice);
    if (token === expectedToken) {
      return true;
    }
  }
  return false;
}

function generateTOTP(secret, timeSlice) {
  const crypto = require('crypto');

  // Convert base32 secret to buffer
  const key = Buffer.from(secret, 'base32');

  // Convert time slice to 8-byte buffer
  const time = Buffer.alloc(8);
  time.writeUInt32BE(Math.floor(timeSlice / 0x100000000), 0);
  time.writeUInt32BE(timeSlice & 0xffffffff, 4);

  // Generate HMAC
  const hmac = crypto.createHmac('sha1', key);
  hmac.update(time);
  const digest = hmac.digest();

  // Extract 4-byte dynamic code
  const offset = digest[digest.length - 1] & 0x0f;
  const code =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);

  // Return 6-digit code
  return (code % 1000000).toString().padStart(6, '0');
}

// Encryption functions using TOTP as key
function encryptMessage(message, totpCode) {
  const salt = crypto.randomBytes(16);
  // Derive key from TOTP code
  const key = crypto.pbkdf2Sync(totpCode, salt, 100000, 32, 'sha256');
  const iv = crypto.randomBytes(12);

  const cipher = crypto.createCipherGCM('aes-256-gcm', key);
  cipher.setAAD(Buffer.from('encrypted-chat'));

  let encrypted = cipher.update(message, 'utf8');
  encrypted = Buffer.concat([encrypted, cipher.final()]);

  const authTag = cipher.getAuthTag();

  // Combine salt + iv + authTag + encrypted
  const combined = Buffer.concat([salt, iv, authTag, encrypted]);

  return {
    encrypted: combined.toString('hex'),
    iv: iv.toString('hex'),
  };
}

function decryptMessage(encryptedHex, ivHex, totpCode) {
  const combined = Buffer.from(encryptedHex, 'hex');

  // Extract components
  const salt = combined.slice(0, 16);
  const iv = combined.slice(16, 28);
  const authTag = combined.slice(28, 44);
  const encrypted = combined.slice(44);

  const key = crypto.pbkdf2Sync(totpCode, salt, 100000, 32, 'sha256');

  const decipher = crypto.createDecipherGCM('aes-256-gcm', key);
  decipher.setAAD(Buffer.from('encrypted-chat'));
  decipher.setAuthTag(authTag);

  let decrypted = decipher.update(encrypted, null, 'utf8');
  decrypted += decipher.final('utf8');

  return decrypted;
}

async function getConversationHistory(sessionId) {
  try {
    const result = await dynamodb
      .query({
        TableName: TABLE_NAME,
        KeyConditionExpression: 'sessionId = :sessionId',
        ExpressionAttributeValues: {
          ':sessionId': sessionId,
        },
        ScanIndexForward: true,
      })
      .promise();

    return result.Items.map(item => ({
      role: item.role,
      content: item.content,
    }));
  } catch (error) {
    console.error('Error getting history:', error);
    return [];
  }
}

async function storeMessage(sessionId, role, content) {
  const timestamp = new Date().toISOString();

  await dynamodb
    .put({
      TableName: TABLE_NAME,
      Item: {
        sessionId: sessionId,
        timestamp: timestamp,
        role: role,
        content: content,
        ttl: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60, // 30 days TTL
      },
    })
    .promise();
}

async function getHistory(sessionId, totpCode, headers) {
  try {
    // Verify TOTP
    const isValidTotp = verifyTOTP(totpCode, process.env.TOTP_SECRET);
    if (!isValidTotp) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: 'Invalid TOTP code' }),
      };
    }

    const encryptedHistory = await getConversationHistory(sessionId);

    // Decrypt history for display
    const decryptedHistory = encryptedHistory.map(msg => {
      if (msg.content.startsWith('ENCRYPTED:')) {
        const parts = msg.content.split(':');
        const msgEncrypted = parts[1];
        const msgIv = parts[2];
        return {
          role: msg.role,
          content: decryptMessage(msgEncrypted, msgIv, totpCode),
        };
      }
      return msg;
    });

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        history: decryptedHistory,
      }),
    };
  } catch (error) {
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Failed to get history: ' + error.message }),
    };
  }
}
