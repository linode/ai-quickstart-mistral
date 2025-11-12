# One-Click AI Sandbox

A Linode Marketplace App that deploys a complete, pre-configured AI inference stack with both a chat UI and an OpenAI-compatible API endpoint in minutes.

## 🚀 Quick Start

Deploy a GPU instance through the Linode Marketplace and be chatting with your own private AI model within 3-5 minutes—no code required.

## ✨ Features

- **One-Click Deployment**: Fully automated setup via Linode Marketplace
- **Complete AI Stack**: Includes both a web-based chat interface and an OpenAI-compatible API
- **Pre-Configured**: NVIDIA drivers, Docker, and all dependencies pre-installed
- **Fast Time-to-Value**: From instance boot to working AI in under 5 minutes
- **Model Flexibility**: Choose any model from Hugging Face at deployment
- **OpenAI-Compatible API**: Drop-in replacement for OpenAI endpoints—just change your `BASE_URL`

## 🏗️ Architecture

The AI Sandbox consists of two containerized services:

1. **API Service** (`vLLM`): High-performance inference engine running on port `8000`
   - OpenAI-compatible REST API
   - Supports any Hugging Face model
   - GPU-accelerated inference

2. **UI Service** (`Open WebUI`): Feature-rich chat interface on port `3000`
   - Browser-based chat UI
   - Persistent chat history
   - Connected to the API service automatically

Both services are managed via Docker Compose and configured to restart automatically.

## 📋 Requirements

- A Linode GPU instance (any supported GPU instance type)
- The "One-Click AI Sandbox" Marketplace App

## 🎯 Use Cases

### For AI Explorers
Try the latest open-source models (like Llama 3) in a chat interface without writing code or paying per-token API fees.

### For Backend Engineers
Get a stable, OpenAI-compatible API endpoint. Point your existing application to your own endpoint by simply changing the `BASE_URL`.

### For Full-Stack Developers
Use the chat UI to experiment with prompts, then use the same underlying API in your application for consistent results.

## 🚦 Getting Started

### Deployment

1. Navigate to the Linode Marketplace
2. Select "One-Click AI Sandbox"
3. Choose your GPU instance type
4. Configure the deployment:
   - **Model ID**: Enter any Hugging Face model ID (e.g., `meta-llama/Llama-3-8B-Instruct`)
   - Default: `mistralai/Mistral-7B-Instruct-v0.3`
5. Deploy and wait 3-5 minutes for services to start

### Accessing Your Services

Once deployed, access your services at:

- **Chat UI**: `http://YOUR_INSTANCE_IP:3000`
- **API Endpoint**: `http://YOUR_INSTANCE_IP:8000/v1`

### API Usage

The API is fully OpenAI-compatible. Example:

```bash
curl http://YOUR_INSTANCE_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.3",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## 🔒 Security

**⚠️ IMPORTANT**: By default, both services are exposed to the internet without authentication.

**You must configure a Linode Cloud Firewall** to protect:
- Port `3000` (UI)
- Port `8000` (API)

A security warning is displayed in the system Message of the Day (`/etc/motd`) when you SSH into the instance.

## 🛠️ Maintenance

### Updating Services

To update the containers, edit `/opt/ai-sandbox/docker-compose.yml` and run:

```bash
cd /opt/ai-sandbox
docker-compose up -d
```

### Changing Models

To switch models, update the `MODEL_ID` environment variable in `/opt/ai-sandbox/docker-compose.yml` and restart:

```bash
cd /opt/ai-sandbox
docker-compose down
docker-compose up -d
```

### Viewing Logs

```bash
cd /opt/ai-sandbox
docker-compose logs -f
```

## 📁 Directory Structure

- `/opt/models` - Model cache directory
- `/opt/open-webui` - Chat UI persistent data
- `/opt/ai-sandbox/docker-compose.yml` - Service configuration

## 🔧 Technical Details

### Base Image

The Marketplace App deploys on a custom Ubuntu 22.04 LTS image with:
- NVIDIA Drivers (latest stable)
- Docker Engine
- Docker Compose v2

### Services

- **API**: `ghcr.io/vllm-project/vllm-openai:latest`
- **UI**: `ghcr.io/open-webui/open-webui:main`

## 📝 Limitations (V1)

- No automatic API authentication (use firewall)
- No user accounts for the UI (open by default)
- No automatic HTTPS/SSL
- Inference only (no fine-tuning support)

## 🤝 Contributing

This is a Linode Marketplace App. For issues or feature requests, please open an issue in this repository.

## 📄 License

[Add license information here]

---

**Status**: Draft v1.0  
**Product**: Akamai Cloud / Linode Marketplace

