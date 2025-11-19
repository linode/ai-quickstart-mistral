# AI Quickstart - Mistral LLM Deployment Scripts

Scripts for automated deployment of AI Quickstart - Mistral LLM on Linode GPU instances.

## Prerequisites

Before using these scripts, ensure you have:

1. **Linode API Access** (one of the following):
   - Linode CLI installed and configured: `pip install linode-cli && linode-cli configure`
   - OR use OAuth authentication (handled automatically by the script)

2. **Required Tools**:
   - `bash` (version 4.0+)
   - `curl` (for API calls)
   - `jq` (for JSON parsing)
   - `ssh` (for instance access)
   - `netcat` (nc) (for connectivity checks)

3. **Optional**:
   - SSH keys in `~/.ssh/` (or script can auto-generate)

## Quick Start

Deploy everything in one command:

```bash
./scripts/deploy.sh
```

The script will guide you through:
1. API authentication (linode-cli or OAuth)
2. Region selection (dynamically fetched from API)
3. GPU instance type selection
4. Instance labeling
5. SSH key configuration
6. Automated deployment and health checks

## Main Script: `deploy.sh`

The main deployment script that handles the complete workflow from instance creation to service validation.

### Usage

```bash
./scripts/deploy.sh
```

### Features

- **Dynamic GPU Availability**: Automatically fetches current GPU availability and pricing from Linode API
- **Multiple Authentication Methods**: Supports linode-cli tokens, OAuth, or environment variables
- **Real-Time Progress Monitoring**: Uses ntfy.sh for live cloud-init progress updates
- **Comprehensive Health Checks**: Verifies containers, Open-WebUI, and vLLM model loading
- **Automatic Cleanup**: Offers to delete failed instances on errors
- **Comprehensive Logging**: All operations logged to timestamped files

### Model Configuration

Default model: `mistralai/Mistral-7B-Instruct-v0.3`

Override with environment variable:
```bash
export MODEL_ID="meta-llama/Llama-3-8B-Instruct"
./scripts/deploy.sh
```

### Output

After successful deployment, the script displays:
- Instance details (ID, IP, region, type)
- Access credentials (SSH, password)
- Service URLs (Open-WebUI, API)
- Log file location

Instance data is saved to: `<instance-label>.json`

## Helper Scripts

Located in `scripts/helpers/`:

### `check_linodecli_token.sh`
Extracts API token from linode-cli configuration.

```bash
./scripts/helpers/check_linodecli_token.sh [--silent]
```

### `linode_oauth.sh`
OAuth flow for token generation (2-hour temporary tokens).

```bash
./scripts/helpers/linode_oauth.sh [--silent]
```

### `get-gpu-availability.sh`
Fetches current GPU availability and pricing from Linode API.

```bash
./scripts/helpers/get-gpu-availability.sh [--silent]
```

## Utility Scripts

### `cleanup-instance.sh`
Delete a test instance.

```bash
./scripts/cleanup-instance.sh <instance-id> [--force]
```

**Example**:
```bash
./scripts/cleanup-instance.sh 12345678
```

## Logging

All deployment operations are logged to timestamped files in the `logs/` directory:
- Format: `logs/deploy-YYYYMMDD-HHMMSS.log`
- Each deployment creates a new log file
- Logs are not committed to git (excluded in `.gitignore`)

### Log Contents

The log file contains:
- Timestamped entries for each deployment step
- API calls and responses
- Instance creation details
- Health check results
- Error messages with full context
- User selections and confirmations

### Viewing Logs

```bash
# View most recent log
ls -t logs/*.log | head -1 | xargs tail -f

# View all logs
ls -lh logs/

# View specific log
tail -f logs/deploy-20240101-120000.log
```

The log file location is displayed:
- At the start of deployment
- In error messages
- In the final summary

## Environment Variables

- `MODEL_ID`: Override default model (default: `mistralai/Mistral-7B-Instruct-v0.3`)
- `LINODE_TOKEN`: API token (if not using linode-cli or OAuth)

**Example**:
```bash
export MODEL_ID="meta-llama/Llama-3-8B-Instruct"
export LINODE_TOKEN="your-token-here"
./scripts/deploy.sh
```

## Troubleshooting

### Script Fails to Start

- **Check dependencies**: Ensure `curl`, `jq`, `ssh`, and `nc` are installed
- **Check log file**: The log file location is shown at the start
- **View latest log**: `ls -t logs/*.log | head -1 | xargs tail -20`

### Authentication Fails

- **Linode CLI**: Run `linode-cli configure` to set up API token
- **OAuth**: Ensure browser can open (script will guide you)
- **Environment variable**: Set `LINODE_TOKEN` if using direct API access
- **Check log file**: Authentication errors are logged with details

### Instance Creation Fails

- **Check API token permissions**: Token must have Linode instance creation permissions
- **Verify GPU access**: Ensure your account has GPU instance access enabled
- **Check available regions**: Script dynamically fetches available regions
- **Check log file**: Full API error responses are logged

### Deployment Fails

- **Wait longer**: Cloud-init may take 3-5 minutes to complete
- **Check SSH connectivity**: `ssh root@<instance-ip>`
- **Check cloud-init logs**: `ssh root@<instance-ip> 'tail -f /var/log/cloud-init-output.log'`
- **Check log file**: Deployment errors include full context

### Services Not Accessible

- **Wait for model loading**: Model download can take 5-10 minutes
- **Check container status**: `ssh root@<instance-ip> 'docker ps'`
- **Check service logs**: `ssh root@<instance-ip> 'cd /opt/ai-llm-basic && docker compose logs'`
- **Check health endpoints**: 
  - Open-WebUI: `curl http://<instance-ip>:3000/health`
  - vLLM: `curl http://<instance-ip>:8000/v1/models`
- **Check log file**: Health check results are logged

### Model Not Loading

- **Check vLLM logs**: `ssh root@<instance-ip> 'docker logs vllm'`
- **Check GPU availability**: `ssh root@<instance-ip> 'nvidia-smi'`
- **Verify model ID**: Check that the model ID is correct and accessible
- **Check log file**: Model loading progress is logged

## Workflow Examples

### Standard Deployment

1. **Run deployment script**:
   ```bash
   ./scripts/deploy.sh
   ```

2. **Follow interactive prompts**:
   - Select region
   - Select instance type
   - Provide instance label
   - Configure SSH key
   - Confirm deployment

3. **Wait for deployment** (10-15 minutes):
   - Instance creation
   - Cloud-init installation
   - Container startup
   - Model loading

4. **Access services**:
   - Open-WebUI: `http://<instance-ip>:3000`
   - API: `http://<instance-ip>:8000/v1`

### Custom Model Deployment

```bash
export MODEL_ID="meta-llama/Llama-3-8B-Instruct"
./scripts/deploy.sh
```

### Cleanup After Testing

```bash
# Get instance ID from deployment output or .json file
./scripts/cleanup-instance.sh <instance-id>
```

## Next Steps

After successful deployment:

1. **Access Open-WebUI**: `http://<instance-ip>:3000`
   - Create admin user on first login
   - Start chatting with the model

2. **Test API**: `http://<instance-ip>:8000/v1`
   - OpenAI-compatible endpoints
   - See [API Usage Guide](../docs/api-usage.md)

3. **Configure Security**:
   - Set up Linode Cloud Firewall
   - Restrict access to trusted IPs
   - See [Security Guide](../docs/security.md)

4. **Review Logs**: Check `logs/deploy-*.log` for deployment details

## Non-Interactive Mode

For CI/CD and automation, see [Non-Interactive Mode Design](../docs/non-interactive-mode.md) for proposed implementation.
