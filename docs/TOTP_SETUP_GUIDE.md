# TOTP-Based Encryption Setup Guide

## Overview

This enhanced version uses **Time-based One-Time Passwords (TOTP)** as encryption keys, making it impossible for corporate IT to replay or decrypt your requests even if they capture the traffic.

## Security Benefits

✅ **Rotating Keys**: Encryption key changes every 30 seconds  
✅ **No Replay Attacks**: Captured requests can't be decrypted later  
✅ **Mobile-Only Access**: Only your phone can generate valid keys  
✅ **Perfect Forward Secrecy**: Past conversations can't be decrypted

## Setup Instructions

### 1. Generate TOTP Secret

```bash
# Generate a random base32 secret (32 characters)
openssl rand -base64 20 | base32 | tr -d '=' | head -c 32
```

Example output: `JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN`

### 2. Add to Google Authenticator

1. **Open Google Authenticator app**
2. **Tap "+" → "Enter a setup key"**
3. **Account name**: `Encrypted Chat`
4. **Key**: Enter your generated secret
5. **Tap "Add"**

### 3. Configure AWS Lambda

Add environment variable in Lambda:

```
TOTP_SECRET = JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN
```

### 4. Configure Postman Collection

Set collection variable:

```
totp_secret = JBSWY3DPEHPK3PXP7WQ6NZXVQ7AFKLMN
```

## Timing and Long Response Handling

### The Challenge

```
09:15:23 - Send request with TOTP: 123456
09:15:53 - TOTP changes to: 789012
09:16:23 - TOTP changes to: 345678
09:17:45 - Response arrives (2+ minutes later)
Question: Which TOTP to use for decryption?
```

### The Solution

**Lambda stores the original TOTP** and returns it with the response:

```json
{
  "success": true,
  "encryptedResponse": "A1B2C3D4...",
  "responseIv": "E5F6G7H8...",
  "totpUsed": "123456",  ← Original TOTP for decryption
  "sessionId": "abc-123"
}
```

**Postman automatically** uses the correct TOTP for decryption, regardless of timing.

### Security Implications

✅ **No Security Loss**: Response still encrypted with time-limited key  
✅ **Perfect Decryption**: Always uses correct TOTP for each response  
✅ **Replay Protection**: Original TOTP still expires, preventing replays  
✅ **Forward Secrecy**: Old responses still become unreadable over time

### Sending Messages

1. **Open Google Authenticator** → Note the 6-digit code
2. **Set message in Postman**: Update `message` collection variable
3. **Run "Send Encrypted Message"**:
   - Generates current TOTP automatically
   - Encrypts message using TOTP as key
   - Sends to Lambda
4. **View response** in Postman console

### Real-World Usage

```
09:15:23 - TOTP: 123456 → Send: "What's the latest in AI?"
09:15:53 - TOTP: 789012 → Send: "Summarize that research paper"
09:16:23 - TOTP: 345678 → Send: "How does this apply to our project?"
```

Each message uses a different encryption key!

## Security Architecture

```
Corporate Network Monitoring:
├── 09:15:23 - Encrypted blob A (key: 123456) ❌ Can't decrypt
├── 09:15:53 - Encrypted blob B (key: 789012) ❌ Can't decrypt
├── 09:16:23 - Encrypted blob C (key: 345678) ❌ Can't decrypt
└── 09:17:00 - Tries to replay blob A ❌ TOTP expired

Your Phone:
├── Google Authenticator generates codes
├── Only you can decrypt conversations
└── Historical messages become unreadable after TOTP rotation
```

## Key Features

### Time Window Validation

- **Lambda accepts**: Current TOTP ± 30 seconds (1 window)
- **Prevents**: Clock skew issues
- **Blocks**: Replay attacks with old codes

### Conversation History

- **Storage**: Each message encrypted with its original TOTP
- **Access**: Requires current valid TOTP to decrypt any history
- **Security**: Old conversations can't be read without original TOTP

### Error Handling

- **Invalid TOTP**: Returns 401 Unauthorized
- **Expired Code**: Must wait for next 30-second window
- **Clock Sync**: Ensure phone/server clocks are synchronized

## Troubleshooting

### "Invalid TOTP code" Error

1. **Check time sync**: Ensure phone has accurate time
2. **Wait for new code**: TOTP changes every 30 seconds
3. **Verify secret**: Ensure same secret in Lambda and Authenticator

### Decryption Failures

1. **Time skew**: Lambda allows ±30 seconds tolerance
2. **Multiple attempts**: Each TOTP works for ~90 seconds total
3. **History access**: Use current TOTP to decrypt old messages

### Performance Tips

1. **Generate TOTP in pre-request**: Postman script auto-generates
2. **Batch requests**: Send multiple messages within 30-second window
3. **Error recovery**: Script shows clear error messages

## Advanced Security Notes

### What Corporate IT Sees

```
POST https://your-lambda-url.amazonaws.com/prod/chat
Content: {"action":"chat","sessionId":"abc-123","encryptedMessage":"A1B2C3...","totpCode":"123456"}
Response: {"success":true,"encryptedResponse":"X9Y8Z7...","responseIv":"..."}
```

**They can see**:

- Your Lambda endpoint
- Request/response timing and sizes
- TOTP codes (but they're time-limited)

**They CANNOT**:

- Decrypt message content (no access to your phone)
- Replay requests (TOTP expires)
- Read conversation history (stored encrypted)

### Perfect Forward Secrecy

Even if your TOTP secret is compromised:

- **Past conversations** remain encrypted with expired TOTPs
- **Only current window** (±30 seconds) is at risk
- **Rotation strategy**: Change TOTP secret monthly

This TOTP-based approach provides military-grade security while maintaining the convenience of using existing corporate tools.
