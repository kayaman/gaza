/**
 * Vercel Serverless Function for Chat API
 * TypeScript implementation of the secure chat proxy
 */

import { VercelRequest, VercelResponse } from "@vercel/node";
import crypto from "crypto";

// Types
interface ChatRequest {
  action: string;
  sessionId: string;
  encryptedMessage: string;
  iv: string;
  totpCode: string;
}

interface ChatResponse {
  success: boolean;
  encryptedResponse?: string;
  responseIv?: string;
  totpUsed?: string;
  sessionId?: string;
  error?: {
    code: string;
    message: string;
  };
  requestId: string;
  timestamp: string;
}

// Configuration
const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const TOTP_SECRET = process.env.TOTP_SECRET;
const TIME_STEP = 30;
const TOTP_WINDOW = 1;

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, X-Requested-With",
  "Content-Type": "application/json",
};

/**
 * Main handler function
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  const requestId = generateRequestId();
  const startTime = Date.now();

  try {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return res
        .status(200)
        .setHeader("Access-Control-Allow-Origin", "*")
        .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        .setHeader(
          "Access-Control-Allow-Headers",
          "Content-Type, Authorization, X-Requested-With"
        )
        .end();
    }

    // Validate HTTP method
    if (req.method !== "POST") {
      return createErrorResponse(res, 405, "Method not allowed", requestId);
    }

    // Validate request body
    if (!req.body || typeof req.body !== "object") {
      return createErrorResponse(res, 400, "Invalid request body", requestId);
    }

    const { action, sessionId, encryptedMessage, iv, totpCode } =
      req.body as ChatRequest;

    // Validate required fields
    if (!sessionId || !encryptedMessage || !iv || !totpCode) {
      return createErrorResponse(
        res,
        400,
        "Missing required fields",
        requestId
      );
    }

    // Verify TOTP
    if (!verifyTOTP(totpCode, TOTP_SECRET!)) {
      return createErrorResponse(
        res,
        401,
        "Invalid or expired TOTP code",
        requestId
      );
    }

    // Decrypt message
    const decryptedMessage = decryptMessage(encryptedMessage, iv, totpCode);

    // Call Anthropic API
    const anthropicResponse = await callAnthropicAPI([
      { role: "user", content: decryptedMessage },
    ]);

    // Encrypt response
    const encryptedResponse = encryptMessage(anthropicResponse, totpCode);

    // Create successful response
    const response: ChatResponse = {
      success: true,
      encryptedResponse: encryptedResponse.encrypted,
      responseIv: encryptedResponse.iv,
      totpUsed: totpCode,
      sessionId,
      requestId,
      timestamp: new Date().toISOString(),
    };

    // Set headers and send response
    Object.entries(corsHeaders).forEach(([key, value]) => {
      res.setHeader(key, value);
    });

    console.log(`Chat request completed in ${Date.now() - startTime}ms`);
    return res.status(200).json(response);
  } catch (error) {
    console.error("Chat handler error:", error);
    return createErrorResponse(res, 500, "Internal server error", requestId);
  }
}

/**
 * Verify TOTP code
 */
function verifyTOTP(token: string, secret: string): boolean {
  if (!token || !/^\d{6}$/.test(token)) {
    return false;
  }

  const currentTime = Math.floor(Date.now() / 1000 / TIME_STEP);

  for (let i = -TOTP_WINDOW; i <= TOTP_WINDOW; i++) {
    const timeSlice = currentTime + i;
    const expectedToken = generateTOTP(secret, timeSlice);

    if (token === expectedToken) {
      return true;
    }
  }

  return false;
}

/**
 * Generate TOTP code
 */
function generateTOTP(secret: string, timeSlice: number): string {
  // Simple TOTP implementation for Vercel
  // In production, use a proper HMAC-SHA1 implementation
  let hash = 0;
  for (let i = 0; i < secret.length; i++) {
    hash = ((hash << 5) - hash + secret.charCodeAt(i) + timeSlice) & 0xffffffff;
  }

  const code = Math.abs(hash) % 1000000;
  return code.toString().padStart(6, "0");
}

/**
 * Encrypt message using AES-256-GCM
 */
function encryptMessage(
  message: string,
  totpCode: string
): { encrypted: string; iv: string } {
  const salt = crypto.randomBytes(16);
  const key = crypto.pbkdf2Sync(totpCode, salt, 100000, 32, "sha256");
  const iv = crypto.randomBytes(12);

  const cipher = crypto.createCipherGCM("aes-256-gcm", key);
  cipher.setAAD(Buffer.from("secure-ai-chat-proxy"));

  let encrypted = cipher.update(message, "utf8");
  encrypted = Buffer.concat([encrypted, cipher.final()]);

  const authTag = cipher.getAuthTag();
  const combined = Buffer.concat([salt, iv, authTag, encrypted]);

  return {
    encrypted: combined.toString("hex"),
    iv: iv.toString("hex"),
  };
}

/**
 * Decrypt message using AES-256-GCM
 */
function decryptMessage(
  encryptedHex: string,
  ivHex: string,
  totpCode: string
): string {
  const combined = Buffer.from(encryptedHex, "hex");

  const salt = combined.slice(0, 16);
  const iv = combined.slice(16, 28);
  const authTag = combined.slice(28, 44);
  const encrypted = combined.slice(44);

  const key = crypto.pbkdf2Sync(totpCode, salt, 100000, 32, "sha256");

  const decipher = crypto.createDecipherGCM("aes-256-gcm", key);
  decipher.setAAD(Buffer.from("secure-ai-chat-proxy"));
  decipher.setAuthTag(authTag);

  let decrypted = decipher.update(encrypted, null, "utf8");
  decrypted += decipher.final("utf8");

  return decrypted;
}

/**
 * Call Anthropic API
 */
async function callAnthropicAPI(
  messages: Array<{ role: string; content: string }>
): Promise<string> {
  const response = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-3-sonnet-20240229",
      max_tokens: 4000,
      messages,
    }),
  });

  if (!response.ok) {
    throw new Error(`Anthropic API error: ${response.status}`);
  }

  const data = await response.json();

  if (!data.content || !data.content[0] || !data.content[0].text) {
    throw new Error("Invalid response from Anthropic API");
  }

  return data.content[0].text;
}

/**
 * Create error response
 */
function createErrorResponse(
  res: VercelResponse,
  statusCode: number,
  message: string,
  requestId: string
) {
  const errorResponse = {
    success: false,
    error: {
      code: getErrorCodeFromStatus(statusCode),
      message,
    },
    requestId,
    timestamp: new Date().toISOString(),
  };

  Object.entries(corsHeaders).forEach(([key, value]) => {
    res.setHeader(key, value);
  });

  return res.status(statusCode).json(errorResponse);
}

/**
 * Get error code from HTTP status
 */
function getErrorCodeFromStatus(statusCode: number): string {
  const statusToCode: { [key: number]: string } = {
    400: "BAD_REQUEST",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    405: "METHOD_NOT_ALLOWED",
    429: "RATE_LIMITED",
    500: "INTERNAL_ERROR",
    502: "BAD_GATEWAY",
    503: "SERVICE_UNAVAILABLE",
  };

  return statusToCode[statusCode] || "UNKNOWN_ERROR";
}

/**
 * Generate request ID
 */
function generateRequestId(): string {
  return `req-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}
