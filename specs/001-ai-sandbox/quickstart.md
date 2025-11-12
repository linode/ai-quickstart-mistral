# Quickstart Guide: One-Click AI Sandbox

**Last Updated**: 2025-11-12

## Overview

Deploy a complete AI inference stack with both a chat interface and OpenAI-compatible API in under 5 minutes. No code or manual configuration required.

## Prerequisites

- Linode account with GPU instance access
- Access to Linode Marketplace
- Web browser (for chat interface)
- Optional: API client for programmatic access

## Deployment

### Step 1: Launch Marketplace App

1. Log in to your Linode account
2. Navigate to **Marketplace** → **Apps**
3. Search for **"One-Click AI Sandbox"**
4. Click **Create** or **Deploy**

### Step 2: Configure Instance

1. **Select GPU Instance Type**: Choose any supported Linode GPU instance
   - Recommended: `g1-gpu-rtx6000-1` or larger for best performance
   - Minimum: Any GPU instance type (check resource requirements)

2. **Region**: Select your preferred data center region

3. **Root Password**: Set a strong root password for SSH access

4. **StackScript Configuration**: 
   - **Model ID**: Leave as default (`mistralai/Mistral-7B-Instruct-v0.3`) or specify a different Hugging Face model
   - Note: Model selection is fixed in v1 - this field is for future use

5. **Label**: Optionally name your instance (e.g., "AI Sandbox - Production")

### Step 3: Deploy and Wait

1. Click **Create Linode**
2. Wait 3-5 minutes for deployment to complete
3. Monitor deployment status in Linode dashboard

### Step 4: Verify Deployment

1. **SSH into instance** (optional, for verification):
   ```bash
   ssh root@YOUR_INSTANCE_IP
   ```

2. **Check deployment status**:
   - View `/etc/motd` for deployment status and access instructions
   - Check service status: `docker-compose -f /opt/ai-sandbox/docker-compose.yml ps`

3. **Verify services are running**:
   - API: `curl http://localhost:8000/health` (if available)
   - UI: Open `http://YOUR_INSTANCE_IP:3000` in browser

## Accessing Services

### Chat Interface (Web UI)

1. **Open in browser**: `http://YOUR_INSTANCE_IP:3000`
2. **Start chatting**: No login required in v1 - interface is immediately available
3. **Chat history**: Automatically saved and persists across browser sessions

**Features**:
- Natural language conversations with AI model
- Persistent chat history
- Multiple conversation threads
- Model information display

### API Endpoint

**Base URL**: `http://YOUR_INSTANCE_IP:8000/v1`

**Example Request** (cURL):
```bash
curl http://YOUR_INSTANCE_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.3",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }'
```

**Example Request** (Python):
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://YOUR_INSTANCE_IP:8000/v1",
    api_key="not-needed"  # No authentication in v1
)

response = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.3",
    messages=[
        {"role": "user", "content": "Explain quantum computing in simple terms"}
    ]
)

print(response.choices[0].message.content)
```

**API Documentation**: See [contracts/openai-api-v1.md](./contracts/openai-api-v1.md) for full API reference.

## Security Configuration

### ⚠️ IMPORTANT: Configure Firewall

**By default, both services are exposed to the internet without authentication.**

**You MUST configure a Linode Cloud Firewall** to protect your deployment:

1. **Create Firewall**:
   - Navigate to **Firewalls** in Linode dashboard
   - Click **Create Firewall**

2. **Configure Rules**:
   - **Inbound Rules**:
     - Allow SSH (port 22) from your IP only
     - Allow HTTP (port 3000) from trusted IPs/networks only
     - Allow HTTP (port 8000) from trusted IPs/networks only
     - Block all other inbound traffic
   - **Outbound Rules**: Allow all (default)

3. **Attach to Instance**:
   - Select your AI Sandbox instance
   - Apply firewall rules

**Alternative**: Use `ufw` or `iptables` on the instance for host-based firewall rules.

### Security Best Practices

- ✅ Restrict API access (port 8000) to trusted IPs only
- ✅ Restrict UI access (port 3000) to trusted IPs only
- ✅ Use strong root password
- ✅ Consider VPN or private network for sensitive deployments
- ❌ Do not expose services to 0.0.0.0/0 without authentication

## Troubleshooting

### Services Not Accessible

**Check service status**:
```bash
cd /opt/ai-sandbox
docker-compose ps
docker-compose logs
```

**Common issues**:
- **Port conflicts**: Check if ports 3000 or 8000 are already in use
- **GPU driver issues**: Verify NVIDIA drivers installed correctly
- **Model download failure**: Check network connectivity, disk space

### Deployment Errors

**Check deployment logs**:
```bash
cat /var/log/ai-sandbox/deployment.log
cat /etc/motd
```

**Common errors**:
- **Model download timeout**: Network issue, retry deployment
- **Insufficient disk space**: Model requires ~14GB free space
- **GPU not detected**: Verify instance type has GPU support

### Service Crashes

**Services auto-restart** on failure. Check logs for root cause:
```bash
docker-compose logs api
docker-compose logs ui
```

**Manual restart**:
```bash
cd /opt/ai-sandbox
docker-compose restart
```

## Maintenance

### Updating Services

1. **Edit docker-compose.yml**:
   ```bash
   nano /opt/ai-sandbox/docker-compose.yml
   ```

2. **Update container image tags** (if needed)

3. **Restart services**:
   ```bash
   cd /opt/ai-sandbox
   docker-compose pull
   docker-compose up -d
   ```

### Changing Models

**Note**: Model selection is fixed in v1. To change models:

1. **Edit docker-compose.yml**:
   ```bash
   nano /opt/ai-sandbox/docker-compose.yml
   ```

2. **Update MODEL_ID environment variable**:
   ```yaml
   environment:
     - MODEL_ID=meta-llama/Llama-3-8B-Instruct  # New model
   ```

3. **Restart services**:
   ```bash
   cd /opt/ai-sandbox
   docker-compose down
   docker-compose up -d
   ```

**Warning**: Changing models will trigger re-download (~14GB+). Ensure sufficient disk space.

### Viewing Logs

**All services**:
```bash
cd /opt/ai-sandbox
docker-compose logs -f
```

**Specific service**:
```bash
docker-compose logs -f api
docker-compose logs -f ui
```

### Backup Chat History

**Chat history location**: `/opt/open-webui`

**Backup**:
```bash
tar -czf chat-history-backup.tar.gz /opt/open-webui
```

**Restore**:
```bash
tar -xzf chat-history-backup.tar.gz -C /
docker-compose restart ui
```

## Next Steps

- **Integrate API**: Point your existing OpenAI applications to this endpoint
- **Experiment**: Try different prompts and use cases
- **Monitor**: Check service logs and resource usage
- **Scale**: Consider multiple instances for higher throughput (future enhancement)

## Support

- **Documentation**: See [spec.md](./spec.md) for full feature specification
- **API Reference**: See [contracts/openai-api-v1.md](./contracts/openai-api-v1.md)
- **Issues**: Report issues via Linode support or repository issues

## Limitations (V1)

- ❌ No authentication (use firewall for access control)
- ❌ No user accounts (chat UI is open by default)
- ❌ No HTTPS/SSL (HTTP only)
- ❌ Fixed model selection (no model switching at deployment)
- ❌ Single-instance only (no horizontal scaling)
- ❌ Sequential request processing (no parallel inference)

These limitations will be addressed in future releases.

