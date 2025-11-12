#!/bin/bash
#
# Purpose:
#   Deploys the AI Sandbox StackScript directly to an existing Linode instance
#   via SSH, bypassing the Marketplace UI. Copies the StackScript and Docker
#   Compose template to the instance and executes the deployment.
#
#   Why it exists: Enables independent deployment workflow for development and
#   testing. Allows deploying to instances created via create-instance.sh or
#   existing instances without Marketplace integration.
#
# Dependencies:
#   - linode-cli: For retrieving instance IP address from instance ID
#   - SSH access: Must have SSH key configured or root password access
#   - StackScript file: stackscripts/ai-sandbox.sh (default)
#   - Docker Compose template: docker/docker-compose.yml.template (optional, has fallback)
#   - Instance must be running and SSH-accessible
#
# Troubleshooting:
#   - "Cannot connect via SSH": Wait longer for instance to boot, check firewall rules
#   - "StackScript file not found": Verify stackscripts/ai-sandbox.sh exists
#   - "SCP copy failed": Check SSH key authentication, verify instance is running
#   - Deployment takes 3-5 minutes: Normal, model download and service startup
#   - Check deployment logs: ssh root@<ip> 'tail -f /var/log/ai-sandbox/deployment.log'
#   - Verify services: Use validate-services.sh script after deployment
#
# Specification Links:
#   - Feature Spec: specs/001-ai-sandbox/spec.md
#   - Tasks: specs/001-ai-sandbox/tasks.md (Phase 3, T042)
#   - StackScript: stackscripts/ai-sandbox.sh
#
# Usage: ./deploy-direct.sh <instance-id> [stackscript-file]

set -euo pipefail

INSTANCE_ID="${1:-}"
STACKSCRIPT_FILE="${2:-stackscripts/ai-sandbox.sh}"
MODEL_ID="${MODEL_ID:-mistralai/Mistral-7B-Instruct-v0.3}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "${INSTANCE_ID}" ]; then
    echo -e "${RED}Error: Instance ID required${NC}"
    echo "Usage: $0 <instance-id> [stackscript-file]"
    echo ""
    echo "To find instance ID: linode-cli linodes list"
    exit 1
fi

if [ ! -f "${STACKSCRIPT_FILE}" ]; then
    echo -e "${RED}Error: StackScript file not found: ${STACKSCRIPT_FILE}${NC}"
    exit 1
fi

# Check if linode-cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo -e "${RED}Error: linode-cli is not installed${NC}"
    exit 1
fi

# Get instance IP
INSTANCE_IP=$(linode-cli linodes view "${INSTANCE_ID}" --json 2>/dev/null | jq -r '.[0].ipv4[0]')

if [ -z "${INSTANCE_IP}" ] || [ "${INSTANCE_IP}" = "null" ]; then
    echo -e "${RED}Error: Could not get IP for instance ${INSTANCE_ID}${NC}"
    exit 1
fi

echo -e "${GREEN}Deploying StackScript to instance ${INSTANCE_ID}...${NC}"
echo "Instance IP: ${INSTANCE_IP}"
echo "StackScript: ${STACKSCRIPT_FILE}"
echo "Model ID: ${MODEL_ID}"
echo ""

# Wait for SSH to be available
wait_for_ssh() {
    local max_attempts=60
    local attempt=0
    local wait_interval=5
    local last_update_time=$(date +%s)
    local update_interval=30  # Show update every 30 seconds
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}⏳ Waiting for SSH connection to be available...${NC}"
    echo -e "${YELLOW}   This can take up to 5 minutes after instance creation${NC}"
    echo -e "${CYAN}   The instance is booting and configuring network services${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    while [ ${attempt} -lt ${max_attempts} ]; do
        # Try SSH connection
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes root@"${INSTANCE_IP}" "echo 'SSH ready'" 2>/dev/null; then
            echo ""
            echo -e "${GREEN}✓ SSH connection established successfully!${NC}"
            echo ""
            return 0
        fi
        
        attempt=$((attempt + 1))
        current_time=$(date +%s)
        elapsed_time=$((current_time - last_update_time))
        
        # Show progress update every 30 seconds
        if [ ${elapsed_time} -ge ${update_interval} ] || [ ${attempt} -eq 1 ]; then
            local total_seconds=$((attempt * wait_interval))
            local minutes=$((total_seconds / 60))
            local seconds=$((total_seconds % 60))
            
            if [ ${minutes} -gt 0 ]; then
                echo -e "${CYAN}⏳ Still waiting... (${minutes}m ${seconds}s elapsed) - Attempt ${attempt}/${max_attempts}${NC}"
            else
                echo -e "${CYAN}⏳ Still waiting... (${seconds}s elapsed) - Attempt ${attempt}/${max_attempts}${NC}"
            fi
            echo -e "${CYAN}   Checking if SSH service is ready on ${INSTANCE_IP}...${NC}"
            echo ""
            last_update_time=${current_time}
        fi
        
        if [ ${attempt} -lt ${max_attempts} ]; then
            sleep ${wait_interval}
        fi
    done
    
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ Error: Could not establish SSH connection after ${max_attempts} attempts${NC}"
    echo -e "${RED}   Total wait time: ~$((max_attempts * wait_interval / 60)) minutes${NC}"
    echo ""
    echo -e "${YELLOW}The instance may still be booting. You can:${NC}"
    echo -e "${YELLOW}  1. Wait a few more minutes and try again:${NC}"
    echo -e "     ${CYAN}./scripts/deploy-direct.sh ${INSTANCE_ID}${NC}"
    echo -e "${YELLOW}  2. Check instance status:${NC}"
    echo -e "     ${CYAN}linode-cli linodes view ${INSTANCE_ID}${NC}"
    echo -e "${YELLOW}  3. Verify instance is running and has an IP address${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    return 1
}

# Wait for SSH to be available before proceeding
if ! wait_for_ssh; then
    exit 1
fi

# Copy StackScript and template to instance
echo "Copying files to instance..."

# Create directory on remote instance
ssh root@"${INSTANCE_IP}" "mkdir -p /opt/ai-sandbox"

# Create temporary directory for files
TEMP_DIR=$(mktemp -d)
cp "${STACKSCRIPT_FILE}" "${TEMP_DIR}/ai-sandbox.sh"
cp docker/docker-compose.yml.template "${TEMP_DIR}/docker-compose.yml.template" 2>/dev/null || true

# Copy files via SCP (SSH is now verified to be available)
scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${TEMP_DIR}/ai-sandbox.sh" root@"${INSTANCE_IP}":/opt/ai-sandbox/ai-sandbox.sh
if [ -f "${TEMP_DIR}/docker-compose.yml.template" ]; then
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${TEMP_DIR}/docker-compose.yml.template" root@"${INSTANCE_IP}":/opt/ai-sandbox/docker-compose.yml.template
fi

echo -e "${GREEN}✓ Files copied successfully${NC}"

# Make StackScript executable
ssh root@"${INSTANCE_IP}" "chmod +x /opt/ai-sandbox/ai-sandbox.sh"

# Run the StackScript
echo ""
echo "Running StackScript..."
echo "This will take 3-5 minutes..."

# Run StackScript with MODEL_ID environment variable
ssh root@"${INSTANCE_IP}" "MODEL_ID=${MODEL_ID} /opt/ai-sandbox/ai-sandbox.sh" || {
    echo -e "${YELLOW}StackScript execution completed (check logs for details)${NC}"
}

# Cleanup
rm -rf "${TEMP_DIR}"

echo ""
echo -e "${GREEN}Deployment initiated!${NC}"
echo ""
echo "Monitor deployment:"
echo "  ssh root@${INSTANCE_IP} 'tail -f /var/log/ai-sandbox/deployment.log'"
echo ""
echo "Check status:"
echo "  ssh root@${INSTANCE_IP} 'cat /etc/motd'"
echo ""
echo "Validate services:"
echo "  ./scripts/validate-services.sh ${INSTANCE_IP}"

