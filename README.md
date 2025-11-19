# AI Quickstart - Mistral 7B LLM

Deploy a complete, pre-configured AI inference stack with both a chat UI and an OpenAI-compatible API endpoint in minutes on Linode GPU instances.

## 🚀 Quick Start

Get started quickly by deploying to a clean Linode GPU instance. See the [Quick Start Guide](docs/quickstart.md) for step-by-step instructions.

## ✨ Features

- **One-Click Deployment**: Fully automated setup via cloud-init
- **Complete AI Stack**: Includes both a web-based chat interface and an OpenAI-compatible API
- **Pre-Configured**: NVIDIA drivers, Docker, and all dependencies pre-installed
- **Fast Time-to-Value**: From instance boot to working AI in under 5 minutes
- **Pre-Configured Model**: Defaults to Mistral 7B Instruct
- **OpenAI-Compatible API**: Drop-in replacement for OpenAI endpoints—just change your `BASE_URL`

## 🏗️ Architecture

AI Quickstart - Mistral LLM consists of two containerized services working together to provide a complete AI inference stack. See the [Architecture Documentation](docs/architecture.md) for detailed information.

## 📋 Requirements

- A Linode account with GPU access enabled
  - **Note**: GPU instances require GPU access to be enabled on your account. If you don't see GPU instance types available, please contact Linode Support to enable GPU access.
- Local system requirements:
  - `bash` (version 4.0+)
  - `curl` (for API calls)
  - `jq` (for JSON parsing)
  - `ssh` (for instance access)
  - `netcat` (nc) (for connectivity checks)
- Authentication (one of the following):
  - Linode CLI configured: `pip install linode-cli && linode-cli configure`
  - OR use OAuth authentication (handled automatically by deployment script)

## 🎯 Use Cases

### For AI Explorers
Try Mistral-7B in a chat interface without writing code or paying per-token API fees.

### For Backend Engineers
Get a stable, OpenAI-compatible API endpoint. Point your existing application to your own endpoint by simply changing the `BASE_URL`.

### For Full-Stack Developers
Use the chat UI to experiment with prompts, then use the same underlying API in your application for consistent results.

## 🚦 Getting Started

### Quick Deployment

Deploy everything in one command:

```bash
./scripts/deploy.sh
```

The script will guide you through:
1. API authentication (linode-cli or OAuth)
2. GPU availability fetching (dynamically fetched from API)
3. Region selection
4. GPU instance type selection
5. Instance labeling
6. Root password configuration
7. SSH key configuration
8. Deployment confirmation
9. Instance creation
10. Automated deployment monitoring and health checks

### Detailed Instructions

See the [Quick Start Guide](docs/quickstart.md) for step-by-step instructions. The guide covers:

- Prerequisites and setup
- Deploying to a clean Linode GPU instance
- Accessing your services after deployment
- Troubleshooting common issues

See [Scripts Documentation](scripts/README.md) for detailed script usage and options.

## 🔒 Security

**⚠️ IMPORTANT**: By default, both services are exposed to the internet without authentication. You must configure a Linode Cloud Firewall to protect your services.

See the [Security Guide](docs/security.md) for detailed firewall setup instructions and security best practices.

## 🛠️ Maintenance

Common maintenance tasks including updating services, changing models, viewing logs, and troubleshooting are covered in the [Maintenance Guide](docs/maintenance.md).

## 📝 Limitations (V1)

- No automatic API authentication (use firewall)
- No user accounts for the UI (open by default)
- No automatic HTTPS/SSL
- Inference only (no fine-tuning support)

## 📚 Documentation

- [Quick Start Guide](docs/quickstart.md) - Get started with deployment
- [Scripts Documentation](scripts/README.md) - Deployment script usage and options
- [Architecture](docs/architecture.md) - System architecture and technical details
- [API Usage](docs/api-usage.md) - API reference and integration examples
- [Security Guide](docs/security.md) - Security best practices and firewall setup
- [Maintenance Guide](docs/maintenance.md) - Updating services, changing models, troubleshooting
- [Non-Interactive Mode](docs/non-interactive-mode.md) - Design for CI/CD automation

## 🤝 Contributing

For issues or feature requests, please open an issue in this repository.

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Status**: Draft v1.0

