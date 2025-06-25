/**
 * Vercel Health Check API
 * Provides health status and system information
 */

import { VercelRequest, VercelResponse } from "@vercel/node";

interface HealthResponse {
  status: string;
  timestamp: string;
  service: string;
  version: string;
  environment: string;
  uptime: number;
  requestId: string;
  checks?: {
    anthropic?: { status: string; message: string };
    encryption?: { status: string; message: string };
    totp?: { status: string; message: string };
  };
  system?: {
    memory: NodeJS.MemoryUsage;
    nodeVersion: string;
    platform: string;
  };
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const requestId = generateRequestId();
  const startTime = Date.now();

  try {
    // Set CORS headers
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Content-Type", "application/json");

    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return res.status(200).end();
    }

    // Only allow GET requests
    if (req.method !== "GET") {
      return res.status(405).json({
        success: false,
        error: { code: "METHOD_NOT_ALLOWED", message: "Method not allowed" },
        requestId,
        timestamp: new Date().toISOString(),
      });
    }

    // Determine if detailed health check is requested
    const detailed =
      req.query.detailed === "true" || req.url?.includes("/detailed");

    // Basic health response
    const healthResponse: HealthResponse = {
      status: "healthy",
      timestamp: new Date().toISOString(),
      service: "secure-ai-chat-proxy",
      version: process.env.SERVICE_VERSION || "1.0.0",
      environment: process.env.NODE_ENV || "production",
      uptime: Math.round(process.uptime()),
      requestId,
    };

    // Add detailed checks if requested
    if (detailed) {
      healthResponse.checks = await performDetailedChecks();
      healthResponse.system = {
        memory: process.memoryUsage(),
        nodeVersion: process.version,
        platform: process.platform,
      };
    }

    // Determine overall status
    const overallStatus =
      detailed && healthResponse.checks
        ? determineOverallStatus(healthResponse.checks)
        : "healthy";

    healthResponse.status = overallStatus;

    const responseTime = Date.now() - startTime;
    console.log(
      `Health check completed in ${responseTime}ms - Status: ${overallStatus}`
    );

    // Return appropriate status code
    const statusCode = overallStatus === "healthy" ? 200 : 503;
    return res.status(statusCode).json(healthResponse);
  } catch (error) {
    console.error("Health check error:", error);

    const errorResponse = {
      status: "unhealthy",
      timestamp: new Date().toISOString(),
      service: "secure-ai-chat-proxy",
      error: "Health check failed",
      requestId,
    };

    return res.status(503).json(errorResponse);
  }
}

/**
 * Perform detailed health checks
 */
async function performDetailedChecks(): Promise<
  NonNullable<HealthResponse["checks"]>
> {
  const checks: NonNullable<HealthResponse["checks"]> = {};

  // Check Anthropic API configuration
  checks.anthropic = await checkAnthropicConfig();

  // Check encryption capabilities
  checks.encryption = await checkEncryption();

  // Check TOTP configuration
  checks.totp = checkTOTPConfig();

  return checks;
}

/**
 * Check Anthropic API configuration
 */
async function checkAnthropicConfig(): Promise<{
  status: string;
  message: string;
}> {
  try {
    const apiKey = process.env.ANTHROPIC_API_KEY;

    if (!apiKey) {
      return {
        status: "unhealthy",
        message: "Anthropic API key not configured",
      };
    }

    if (!apiKey.startsWith("sk-ant-")) {
      return {
        status: "unhealthy",
        message: "Invalid Anthropic API key format",
      };
    }

    if (apiKey.length < 100) {
      return {
        status: "unhealthy",
        message: "Anthropic API key appears invalid",
      };
    }

    // Optional: Test API connectivity (commented out to avoid unnecessary API calls)
    // const testResponse = await fetch('https://api.anthropic.com/v1/messages', {
    //   method: 'POST',
    //   headers: {
    //     'x-api-key': apiKey,
    //     'anthropic-version': '2023-06-01',
    //     'content-type': 'application/json'
    //   },
    //   body: JSON.stringify({
    //     model: 'claude-3-sonnet-20240229',
    //     max_tokens: 1,
    //     messages: [{ role: 'user', content: 'test' }]
    //   })
    // });

    return { status: "healthy", message: "Anthropic API key configured" };
  } catch (error) {
    return { status: "unhealthy", message: `Anthropic check failed: ${error}` };
  }
}

/**
 * Check encryption capabilities
 */
async function checkEncryption(): Promise<{ status: string; message: string }> {
  try {
    const crypto = await import("crypto");

    // Test basic crypto operations
    const testData = "test-encryption-data";
    const key = crypto.randomBytes(32);
    const iv = crypto.randomBytes(12);

    const cipher = crypto.createCipherGCM("aes-256-gcm", key);
    let encrypted = cipher.update(testData, "utf8");
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    const authTag = cipher.getAuthTag();

    const decipher = crypto.createDecipherGCM("aes-256-gcm", key);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encrypted, null, "utf8");
    decrypted += decipher.final("utf8");

    if (decrypted !== testData) {
      return { status: "unhealthy", message: "Encryption test failed" };
    }

    return { status: "healthy", message: "Encryption working correctly" };
  } catch (error) {
    return {
      status: "unhealthy",
      message: `Encryption check failed: ${error}`,
    };
  }
}

/**
 * Check TOTP configuration
 */
function checkTOTPConfig(): { status: string; message: string } {
  try {
    const totpSecret = process.env.TOTP_SECRET;

    if (!totpSecret) {
      return { status: "unhealthy", message: "TOTP secret not configured" };
    }

    if (totpSecret.length < 16) {
      return { status: "unhealthy", message: "TOTP secret too short" };
    }

    // Basic Base32 validation
    if (!/^[A-Z2-7]+=*$/.test(totpSecret)) {
      return { status: "unhealthy", message: "Invalid TOTP secret format" };
    }

    return { status: "healthy", message: "TOTP configuration valid" };
  } catch (error) {
    return { status: "unhealthy", message: `TOTP check failed: ${error}` };
  }
}

/**
 * Determine overall status from individual checks
 */
function determineOverallStatus(
  checks: NonNullable<HealthResponse["checks"]>
): string {
  const checkValues = Object.values(checks);

  // If any critical check fails, overall status is unhealthy
  for (const check of checkValues) {
    if (check.status === "unhealthy") {
      return "unhealthy";
    }
  }

  return "healthy";
}

/**
 * Generate request ID
 */
function generateRequestId(): string {
  return `health-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}
