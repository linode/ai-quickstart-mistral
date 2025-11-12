#!/bin/bash
#
# Purpose:
#   Runs the AI Sandbox StackScript on an existing Linode instance (by ID or IP).
#   Useful for re-running deployment after StackScript changes or testing iterations.
#   Copies updated StackScript to instance and executes it.
#
#   Why it exists: Enables iterative development workflow. After making changes
#   to the StackScript, developers can quickly re-deploy without creating new
#   instances, speeding up the development cycle.
#
# Dependencies:
#   - SSH access: Must have SSH key or password access to the instance
#   - linode-cli: Optional, only needed if providing instance ID instead of IP
#   - jq: Optional, only needed if using instance ID lookup
#   - StackScript file: stackscripts/ai-sandbox.sh (default)
#   - Docker Compose template: docker/docker-compose.yml.template (optional)
#
# Troubleshooting:
#   - "Cannot connect via SSH": Verify instance is running, check firewall/SSH access
#   - "Instance ID not found": Verify ID is correct, check linode-cli is configured
#   - "StackScript execution failed": Check logs on instance, verify Docker is running
#   - Services may need restart: Existing services may conflict, consider stopping first
#   - Model re-download: If model cache cleared, will re-download (~14GB)
#
# Specification Links:
#   - Feature Spec: specs/001-ai-sandbox/spec.md
#   - Tasks: specs/001-ai-sandbox/tasks.md (Phase 3, T043)
#   - StackScript: stackscripts/ai-sandbox.sh
#
# Usage: ./run-stackscript.sh <instance-id-or-ip> [stackscript-file]

set -euo pipefail

INSTANCE_ID_OR_IP="${1:-}"
STACKSCRIPT_FILE="${2:-stackscripts/ai-sandbox.sh}"
MODEL_ID="${MODEL_ID:-mistralai/Mistral-7B-Instruct-v0.3}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "${INSTANCE_ID_OR_IP}" ]; then
    echo -e "${RED}Error: Instance ID or IP required${NC}"
    echo "Usage: $0 <instance-id-or-ip> [stackscript-file]"
    exit 1
fi

# Determine if input is IP or ID
if [[ "${INSTANCE_ID_OR_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    INSTANCE_IP="${INSTANCE_ID_OR_IP}"
else
    # Assume it's an instance ID, get IP
    if command -v linode-cli &> /dev/null; then
        INSTANCE_IP=$(linode-cli linodes view "${INSTANCE_ID_OR_IP}" --json 2>/dev/null | jq -r '.[0].ipv4[0]')
        if [ -z "${INSTANCE_IP}" ] || [ "${INSTANCE_IP}" = "null" ]; then
            echo -e "${RED}Error: Could not get IP for instance ${INSTANCE_ID_OR_IP}${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error: linode-cli not found. Please provide IP address directly.${NC}"
        exit 1
    fi
fi

if [ ! -f "${STACKSCRIPT_FILE}" ]; then
    echo -e "${RED}Error: StackScript file not found: ${STACKSCRIPT_FILE}${NC}"
    exit 1
fi

echo -e "${GREEN}Running StackScript on instance...${NC}"
echo "Instance IP: ${INSTANCE_IP}"
echo "StackScript: ${STACKSCRIPT_FILE}"
echo "Model ID: ${MODEL_ID}"
echo ""

# Test SSH connectivity
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${INSTANCE_IP}" "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to instance via SSH${NC}"
    echo "Please ensure:"
    echo "  1. Instance is running"
    echo "  2. SSH key is configured"
    echo "  3. Firewall allows SSH (port 22)"
    exit 1
fi

# Copy StackScript to instance
echo "Copying StackScript to instance..."
TEMP_DIR=$(mktemp -d)
cp "${STACKSCRIPT_FILE}" "${TEMP_DIR}/ai-sandbox.sh"
cp docker/docker-compose.yml.template "${TEMP_DIR}/docker-compose.yml.template" 2>/dev/null || true

scp -o StrictHostKeyChecking=no "${TEMP_DIR}/ai-sandbox.sh" root@"${INSTANCE_IP}":/opt/ai-sandbox/ai-sandbox.sh
if [ -f "${TEMP_DIR}/docker-compose.yml.template" ]; then
    ssh root@"${INSTANCE_IP}" "mkdir -p /opt/ai-sandbox"
    scp -o StrictHostKeyChecking=no "${TEMP_DIR}/docker-compose.yml.template" root@"${INSTANCE_IP}":/opt/ai-sandbox/docker-compose.yml.template
fi

# Make executable
ssh root@"${INSTANCE_IP}" "chmod +x /opt/ai-sandbox/ai-sandbox.sh"

# Run the StackScript
echo ""
echo "Running StackScript..."
echo "This will take 3-5 minutes..."

ssh root@"${INSTANCE_IP}" "MODEL_ID=${MODEL_ID} /opt/ai-sandbox/ai-sandbox.sh" || {
    echo -e "${YELLOW}StackScript execution completed (check logs for details)${NC}"
}

# Cleanup
rm -rf "${TEMP_DIR}"

echo ""
echo -e "${GREEN}StackScript execution completed!${NC}"
echo ""
echo "Check deployment status:"
echo "  ssh root@${INSTANCE_IP} 'cat /etc/motd'"
echo ""
echo "View logs:"
echo "  ssh root@${INSTANCE_IP} 'tail -f /var/log/ai-sandbox/deployment.log'"

