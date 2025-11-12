# OpenAI API v1 Compatibility Contract

**Date**: 2025-11-12  
**Feature**: One-Click AI Sandbox  
**API Version**: OpenAI API v1 (latest stable)

## Overview

The AI Sandbox provides an OpenAI-compatible REST API endpoint that implements the OpenAI Chat Completions API v1. This allows existing applications using OpenAI SDKs to work with minimal changes (only BASE_URL modification).

## Base URL

```
http://{INSTANCE_IP}:8000/v1
```

Where `{INSTANCE_IP}` is the public IP address of the deployed Linode GPU instance.

## Authentication

**Status**: No authentication required in v1 (deferred to future release)

**Security Note**: Users MUST configure Linode Cloud Firewall to restrict access to port 8000. See security documentation for details.

## Endpoints

### POST /v1/chat/completions

Creates a chat completion for the provided messages.

**Request**:
```json
{
  "model": "mistralai/Mistral-7B-Instruct-v0.3",
  "messages": [
    {
      "role": "user",
      "content": "Hello, how are you?"
    }
  ],
  "temperature": 0.7,
  "max_tokens": 1000
}
```

**Request Parameters**:
- `model` (string, required): Model identifier. Must be `mistralai/Mistral-7B-Instruct-v0.3` in v1.
- `messages` (array, required): Array of message objects with `role` and `content`.
  - `role` (string): `"system"`, `"user"`, or `"assistant"`
  - `content` (string): Message content
- `temperature` (number, optional): Sampling temperature (0.0 to 2.0). Default: 1.0
- `max_tokens` (integer, optional): Maximum tokens to generate. Default: model-dependent
- `stream` (boolean, optional): Enable streaming responses. Default: false

**Response** (200 OK):
```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "mistralai/Mistral-7B-Instruct-v0.3",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "I'm doing well, thank you for asking!"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 8,
    "total_tokens": 18
  }
}
```

**Response Fields**:
- `id` (string): Unique completion identifier
- `object` (string): Object type, always `"chat.completion"`
- `created` (integer): Unix timestamp of creation
- `model` (string): Model identifier used
- `choices` (array): Array of completion choices
  - `index` (integer): Choice index
  - `message` (object): Message object with `role` and `content`
  - `finish_reason` (string): Reason for completion (`"stop"`, `"length"`, etc.)
- `usage` (object): Token usage statistics
  - `prompt_tokens` (integer): Tokens in prompt
  - `completion_tokens` (integer): Tokens in completion
  - `total_tokens` (integer): Total tokens used

**Error Responses**:

400 Bad Request - Invalid request format:
```json
{
  "error": {
    "message": "Invalid request format",
    "type": "invalid_request_error",
    "code": "invalid_request"
  }
}
```

429 Too Many Requests - Request queued (sequential processing):
```json
{
  "error": {
    "message": "Request queued, please wait",
    "type": "rate_limit_error",
    "code": "rate_limit_exceeded"
  }
}
```

500 Internal Server Error - Service error:
```json
{
  "error": {
    "message": "Internal server error",
    "type": "server_error",
    "code": "internal_error"
  }
}
```

503 Service Unavailable - Service not ready:
```json
{
  "error": {
    "message": "Service is starting up, please wait",
    "type": "server_error",
    "code": "service_unavailable"
  }
}
```

## Request Processing

### Sequential Processing

**Behavior**: Requests are queued and processed sequentially (one at a time).

**Rationale**: 
- Prevents GPU memory contention
- Ensures consistent response quality
- Simplifies resource management for single-instance deployment

**Implementation**: vLLM handles request queuing internally. Concurrent requests are queued and processed in order.

**Timeout**: Requests may timeout if queue is too long. Recommended timeout: 5 minutes for typical requests.

## Compatibility Notes

### Supported Features
- ✅ Chat completions (standard messages)
- ✅ System messages
- ✅ Temperature and sampling parameters
- ✅ Max tokens limit
- ✅ Token usage statistics
- ✅ Streaming responses (if supported by vLLM)

### Unsupported Features (v1)
- ❌ Model selection (fixed default model)
- ❌ Fine-tuning endpoints
- ❌ Embeddings endpoints
- ❌ Image generation endpoints
- ❌ Authentication/API keys

### Differences from OpenAI API
- Model identifier format: Uses Hugging Face format (`org/model-name`) instead of OpenAI model names
- Sequential processing: Requests queued (vs. parallel processing in OpenAI)
- No authentication: Open by default (firewall protection required)

## Example Usage

### cURL
```bash
curl http://YOUR_INSTANCE_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.3",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

### Python (OpenAI SDK)
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://YOUR_INSTANCE_IP:8000/v1",
    api_key="not-needed"  # No auth in v1
)

response = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.3",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)
```

### JavaScript/TypeScript
```typescript
import OpenAI from 'openai';

const openai = new OpenAI({
  baseURL: 'http://YOUR_INSTANCE_IP:8000/v1',
  apiKey: 'not-needed', // No auth in v1
});

const completion = await openai.chat.completions.create({
  model: 'mistralai/Mistral-7B-Instruct-v0.3',
  messages: [{ role: 'user', content: 'Hello!' }],
});

console.log(completion.choices[0].message.content);
```

## Health Check

### GET /health

Simple health check endpoint (if provided by vLLM).

**Response** (200 OK):
```json
{
  "status": "healthy"
}
```

**Note**: Health check availability depends on vLLM implementation. Primary health check: successful `/v1/chat/completions` request.

## Versioning

**Current Version**: OpenAI API v1 (latest stable)

**Future Versions**: 
- Model selection support (future release)
- Authentication support (future release)
- Additional endpoints (future release)

**Breaking Changes**: Will be versioned and documented per constitution requirements.

