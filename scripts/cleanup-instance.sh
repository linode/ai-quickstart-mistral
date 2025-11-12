#!/bin/bash
#
# Purpose:
#   Deletes a Linode instance created for testing. Safely removes test instances
#   and cleans up associated instance info files. Includes confirmation prompt
#   to prevent accidental deletion of production instances.
#
#   Why it exists: Enables clean development workflow by removing test instances
#   after testing. Prevents accumulation of unused instances and associated costs.
#   Critical for iterative development and testing cycles.
#
# Dependencies:
#   - linode-cli: For deleting instances via Linode API
#   - jq: For parsing instance information from API responses
#   - User confirmation: Interactive prompt (unless --force flag used)
#
# Troubleshooting:
#   - "linode-cli not installed": Install with 'pip install linode-cli'
#   - "Instance not found": Verify instance ID is correct, check it hasn't been deleted
#   - "Permission denied": Check API token has delete permissions for instances
#   - Deletion fails: Verify instance is not in a protected state, check API limits
#   - Instance info file not cleaned: Manually remove .instance-info-<ID>.json if needed
#
# Specification Links:
#   - Tasks: specs/001-ai-sandbox/tasks.md (Phase 3, T046)
#   - Development Workflow: specs/001-ai-sandbox/plan.md
#
# Usage: ./cleanup-instance.sh <instance-id> [--force]

set -euo pipefail

INSTANCE_ID="${1:-}"
FORCE="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "${INSTANCE_ID}" ]; then
    echo -e "${RED}Error: Instance ID required${NC}"
    echo "Usage: $0 <instance-id> [--force]"
    echo ""
    echo "To list instances: linode-cli linodes list"
    exit 1
fi

# Check if linode-cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo -e "${RED}Error: linode-cli is not installed${NC}"
    exit 1
fi

# Get instance info
INSTANCE_INFO=$(linode-cli linodes view "${INSTANCE_ID}" --json 2>/dev/null)

if [ -z "${INSTANCE_INFO}" ] || [ "${INSTANCE_INFO}" = "[]" ]; then
    echo -e "${RED}Error: Instance ${INSTANCE_ID} not found${NC}"
    exit 1
fi

INSTANCE_LABEL=$(echo "${INSTANCE_INFO}" | jq -r '.[0].label')
INSTANCE_IP=$(echo "${INSTANCE_INFO}" | jq -r '.[0].ipv4[0]')

echo -e "${YELLOW}Warning: This will delete the Linode instance!${NC}"
echo ""
echo "Instance Details:"
echo "  ID: ${INSTANCE_ID}"
echo "  Label: ${INSTANCE_LABEL}"
echo "  IP: ${INSTANCE_IP}"
echo ""

if [ "${FORCE}" != "--force" ]; then
    read -p "Are you sure you want to delete this instance? (yes/no): " CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo "Deleting instance ${INSTANCE_ID}..."
if linode-cli linodes delete "${INSTANCE_ID}"; then
    echo -e "${GREEN}✓ Instance deleted successfully${NC}"
    
    # Clean up instance info file if it exists
    INSTANCE_INFO_FILE=".instance-info-${INSTANCE_ID}.json"
    if [ -f "${INSTANCE_INFO_FILE}" ]; then
        rm -f "${INSTANCE_INFO_FILE}"
        echo "Cleaned up instance info file"
    fi
else
    echo -e "${RED}Error: Failed to delete instance${NC}"
    exit 1
fi

