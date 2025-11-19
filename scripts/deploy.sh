#!/usr/bin/env bash

set -euo pipefail

#==============================================================================
# AI Quickstart - Mistral LLM Deployment Script
#
# This script automates the creation of a GPU instance with vLLM and Open-WebUI
# configured for Mistral 7B Instruct model.
#
# Usage:
#   ./deploy.sh
#
#==============================================================================

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Initialize logging
LOG_DIR="${PROJECT_ROOT}/logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="${LOG_DIR}/deploy-${TIMESTAMP}.log"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $*" >> "${LOG_FILE}" 2>/dev/null || true
}

# Initialize logging - redirect stdout/stderr to both terminal and log file
exec > >(tee -a "${LOG_FILE}")
exec 2> >(tee -a "${LOG_FILE}" >&2)

log "=== AI Quickstart - Mistral LLM Deployment Started ==="
log "Script: ${SCRIPT_DIR}/deploy.sh"
log "Working directory: ${PROJECT_ROOT}"
log "Log file: ${LOG_FILE}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# API base URL
readonly API_BASE="https://api.linode.com/v4"

# Default model ID
MODEL_ID="${MODEL_ID:-mistralai/Mistral-7B-Instruct-v0.3}"

# OS Image configuration
UBUNTU_IMAGE="linode/ubuntu24.04"
OS_NAME="Ubuntu"
OS_VERSION="24.04"

# Global variables
TOKEN=""
INSTANCE_LABEL=""
INSTANCE_PASSWORD=""
SSH_PUBLIC_KEY=""
SELECTED_REGION=""
SELECTED_TYPE=""
INSTANCE_IP=""
INSTANCE_ID=""

#==============================================================================
# Helper Functions
#==============================================================================

# Print colored message
print_msg() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

# Print error and exit
error_exit() {
    local message="$1"
    local offer_delete="${2:-false}"

    log "ERROR: ${message}"
    print_msg "$RED" "❌ ERROR: $message"
    echo ""
    print_msg "$YELLOW" "📋 Full log: ${LOG_FILE}"
    echo "   View with: tail -f ${LOG_FILE}"
    echo ""

    # Offer to delete instance if requested and instance was created
    if [ "$offer_delete" = "true" ] && [ -n "${INSTANCE_ID:-}" ]; then
        echo ""
        printf '\n\n\n\033[3A'        # Print 3 blank lines to scroll up
        read -p "$(echo -e ${YELLOW}Do you want to delete the failed instance? [Y/n]:${NC} )" delete_choice
        delete_choice=${delete_choice:-Y}

        if [[ "$delete_choice" =~ ^[Yy]$ ]]; then
            echo ""
            print_msg "$YELLOW" "Deleting instance (ID: ${INSTANCE_ID})..."
            log "Deleting failed instance: ${INSTANCE_ID}"

            if curl -s -X DELETE \
                -H "Authorization: Bearer ${TOKEN}" \
                "${API_BASE}/linode/instances/${INSTANCE_ID}" > /dev/null; then
                success "Instance deleted successfully"
                log "Instance deleted successfully"
            else
                warn "Failed to delete instance. You may need to delete it manually from the Linode Cloud Manager"
                info "Instance ID: ${INSTANCE_ID}"
                log "WARNING: Failed to delete instance ${INSTANCE_ID}"
            fi
        else
            info "Instance was not deleted. You can manage it from the Linode Cloud Manager"
            info "Instance ID: ${INSTANCE_ID}"
            log "User chose not to delete instance ${INSTANCE_ID}"
        fi
    fi

    exit 1
}

# Print success message
success() {
    print_msg "$GREEN" "✅ $*"
    log "SUCCESS: $*"
}

# Print info message
info() {
    print_msg "$CYAN" "ℹ️  $*"
    log "INFO: $*"
}

# Print warning message
warn() {
    print_msg "$YELLOW" "⚠️  $*"
    log "WARNING: $*"
}

# Show banner
show_banner() {
    clear
    cat "${SCRIPT_DIR}/helpers/logo/akamai.txt" 2>/dev/null || {
        echo "==================================="
        echo "  AI Quickstart - Mistral LLM"
        echo "==================================="
    }
    echo ""
}

#==============================================================================
# Show Logo
#==============================================================================
show_banner

print_msg "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_msg "$BOLD" "                    AI Quickstart - Mistral LLM"
print_msg "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_msg "$YELLOW" "This script will:"
echo "  • Ask you to authenticate with your Linode/Akamai Cloud account"
echo "  • Deploy a fully configured GPU instance in your account with:"
echo "    - Operating System: ${OS_NAME} ${OS_VERSION}"
echo "    - Docker and Docker Compose"
echo "    - NVIDIA drivers and Container Toolkit"
echo "    - vLLM (LLM inference server)"
echo "    - Pre-loaded model: ${MODEL_ID}"
echo "    - Open-WebUI (web interface)"
echo ""
print_msg "$GREEN" "Setup time: ~10-15 minutes"
print_msg "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_msg "$CYAN" "📋 Log file: ${LOG_FILE}"
echo ""

sleep 3

#==============================================================================
# Get Token from linode-cli or Linode OAuth
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "🔑 Step 1/10: Obtaining Linode API credentials..."
echo "------------------------------------------------------"
log "Step 1: Obtaining API credentials"

# Try to get token from check_linodecli_token.sh
if [ -f "${SCRIPT_DIR}/helpers/check_linodecli_token.sh" ]; then
    TOKEN=$("${SCRIPT_DIR}/helpers/check_linodecli_token.sh" --silent 2>/dev/null || true)
    if [ -n "$TOKEN" ]; then
        log "Token obtained from linode-cli"
    fi
fi

# If no token, try OAuth
if [ -z "$TOKEN" ] && [ -f "${SCRIPT_DIR}/helpers/linode_oauth.sh" ]; then
    log "Attempting OAuth authentication"
    TOKEN=$("${SCRIPT_DIR}/helpers/linode_oauth.sh" || true)
    if [ -n "$TOKEN" ]; then
        log "Token obtained via OAuth"
    fi
fi

# Verify we have a token
if [ -z "$TOKEN" ]; then
    error_exit "Failed to get API token. Please configure linode-cli or run linode_oauth.sh"
fi

success "API credentials obtained successfully"
echo ""

#==============================================================================
# Get GPU Availability
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "📊 Step 2/10: Fetching GPU availability..."
echo "------------------------------------------------------"
log "Step 2: Fetching GPU availability"

if [ ! -f "${SCRIPT_DIR}/helpers/get-gpu-availability.sh" ]; then
    error_exit "get-gpu-availability.sh not found"
fi

# Export token so get-gpu-availability.sh doesn't need to fetch it again
export LINODE_TOKEN="$TOKEN"

GPU_DATA=$("${SCRIPT_DIR}/helpers/get-gpu-availability.sh" --silent)
log "GPU availability data fetched"

if [ -z "$GPU_DATA" ]; then
    error_exit "Failed to fetch GPU availability data"
fi

info "GPU availability data fetched successfully"
echo ""

#==============================================================================
# Let User Select Region
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "🌍 Step 3/10: Select Region"
echo "------------------------------------------------------"
log "Step 3: Region selection"

# Extract regions with available GPU instances
AVAILABLE_REGIONS=()
while IFS= read -r line; do
    AVAILABLE_REGIONS+=("$line")
done < <(echo "$GPU_DATA" | jq -r '.regions[] | "\(.id)|\(.label)|\(.instance_types | join(","))"')

if [ ${#AVAILABLE_REGIONS[@]} -eq 0 ]; then
    error_exit "No regions with available GPU instances found"
fi

print_msg "$GREEN" "Available Regions:"
echo ""

# Display regions
for i in "${!AVAILABLE_REGIONS[@]}"; do
    IFS='|' read -r region_id region_label types <<< "${AVAILABLE_REGIONS[$i]}"
    printf "${CYAN}%2d.${NC} %-12s %s\n" "$((i+1))" "$region_id" "$region_label"
done

echo ""
while true; do
    printf '\n\n\n\033[3A'        # Print 3 blank lines to scroll up
    read -p "$(echo -e ${YELLOW}Enter region number:${NC} )" region_choice
    if [[ "$region_choice" =~ ^[0-9]+$ ]] && [ "$region_choice" -ge 1 ] && [ "$region_choice" -le ${#AVAILABLE_REGIONS[@]} ]; then
        IFS='|' read -r SELECTED_REGION region_label region_types <<< "${AVAILABLE_REGIONS[$((region_choice-1))]}"
        log "Selected region: ${SELECTED_REGION} (${region_label})"
        break
    else
        warn "Invalid choice. Please enter a number between 1 and ${#AVAILABLE_REGIONS[@]}"
    fi
done

echo "Selected region: $SELECTED_REGION ($region_label)"
echo ""

#==============================================================================
# Let User Select Instance Type
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "💻 Step 4/10: Select Instance Type"
echo "------------------------------------------------------"
log "Step 4: Instance type selection"

# Get available instance types for selected region
print_msg "$GREEN" "Available Instance Types in $SELECTED_REGION:"
echo ""

# Display instance types
declare -a TYPE_OPTIONS=()
i=0
while IFS= read -r type_data; do
    type_id=$(echo "$type_data" | jq -r '.id')
    echo "$region_types" | grep -q "$type_id" || continue

    ((i++))
    TYPE_OPTIONS+=("$type_data")

    # Extract all fields at once and display
    IFS=$'\t' read -r id lbl vcpus mem hr mo < <(echo "$type_data" | jq -r '[.id, .label, .vcpus, (.memory/1024|floor), .hourly, .monthly] | @tsv')
    printf "${CYAN}%2d.${NC} %-25s %-35s ${CYAN}%d vCPUs, %dGB RAM - \$%.2f/hr (\$%.1f/mo)${NC}\n" "$i" "$id" "$lbl" "$vcpus" "$mem" "$hr" "$mo"
    [ "$id" = "g2-gpu-rtx4000a1-s" ] && [ "$i" = "1" ] && printf "    ${MAGENTA}⭐ RECOMMENDED${NC}\n"
done < <(echo "$GPU_DATA" | jq -c '.instance_types[]')

if [ ${#TYPE_OPTIONS[@]} -eq 0 ]; then
    error_exit "No instance types available in selected region"
fi

echo ""
while true; do
    printf '\n\n\n\033[3A'        # Print 3 blank lines to scroll up
    read -p "$(echo -e ${YELLOW}Enter instance type number [default: 1]:${NC} )" type_choice

    # Set default to 1 (g2-gpu-rtx4000a1-s)
    if [ -z "$type_choice" ]; then
        type_choice=1
    fi

    if [[ "$type_choice" =~ ^[0-9]+$ ]] && [ "$type_choice" -ge 1 ] && [ "$type_choice" -le ${#TYPE_OPTIONS[@]} ]; then
        SELECTED_TYPE=$(echo "${TYPE_OPTIONS[$((type_choice-1))]}" | jq -r '.id')
        log "Selected instance type: ${SELECTED_TYPE}"
        break
    else
        warn "Invalid choice. Please enter a number between 1 and ${#TYPE_OPTIONS[@]}"
    fi
done

echo "Selected instance type: $SELECTED_TYPE"
echo ""

#==============================================================================
# Let User Specify Instance Label
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "🏷️  Step 5/10: Instance Label"
echo "------------------------------------------------------"
log "Step 5: Instance label"

DEFAULT_LABEL="ai-quickstart-mistral-$(date +%y%m%d%H%M)"
echo ""
printf '\n\n\n\033[3A'        # Print 3 blank lines to scroll up
read -p "$(echo -e ${YELLOW}Enter instance label [default: $DEFAULT_LABEL]:${NC} )" user_label

if [ -z "$user_label" ]; then
    INSTANCE_LABEL="$DEFAULT_LABEL"
else
    INSTANCE_LABEL="$user_label"
fi

log "Instance label: ${INSTANCE_LABEL}"
echo "Instance label: $INSTANCE_LABEL"
echo ""

#==============================================================================
# Let User Specify Root Password
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "🔐 Step 6/10: Root Password"
echo "------------------------------------------------------"
log "Step 6: Root password configuration"

# Function to generate random password
# Requirements: 12 characters, min 1 uppercase, min 1 lowercase, min 1 number, min 1 symbol
generate_password() {
    local password=""
    local uppercase="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local lowercase="abcdefghijklmnopqrstuvwxyz"
    local numbers="0123456789"
    local symbols="!@#$%^&*()_+-="
    local all_chars="${uppercase}${lowercase}${numbers}${symbols}"
    
    # Build array with required characters
    local chars_array=()
    chars_array+=("${uppercase:$((RANDOM % ${#uppercase})):1}")
    chars_array+=("${lowercase:$((RANDOM % ${#lowercase})):1}")
    chars_array+=("${numbers:$((RANDOM % ${#numbers})):1}")
    chars_array+=("${symbols:$((RANDOM % ${#symbols})):1}")
    
    # Fill remaining 8 characters randomly
    for i in {1..8}; do
        chars_array+=("${all_chars:$((RANDOM % ${#all_chars})):1}")
    done
    
    # Shuffle array using Fisher-Yates algorithm (cross-platform)
    local n=${#chars_array[@]}
    for ((i = n - 1; i > 0; i--)); do
        j=$((RANDOM % (i + 1)))
        # Swap
        local temp="${chars_array[i]}"
        chars_array[i]="${chars_array[j]}"
        chars_array[j]="$temp"
    done
    
    # Combine into password string
    for char in "${chars_array[@]}"; do
        password="${password}${char}"
    done
    
    echo "$password"
}

# Function to validate auto-generated password (exactly 12 characters)
validate_generated_password() {
    local pwd="$1"
    [[ ${#pwd} -eq 12 && "$pwd" =~ [A-Z] && "$pwd" =~ [a-z] && "$pwd" =~ [0-9] && "$pwd" =~ [^A-Za-z0-9] ]]
}

# Function to validate user-provided password (12-64 characters)
validate_user_password() {
    local pwd="$1"
    [[ ${#pwd} -ge 12 && ${#pwd} -le 64 && "$pwd" =~ [A-Z] && "$pwd" =~ [a-z] && "$pwd" =~ [0-9] && "$pwd" =~ [^A-Za-z0-9] ]]
}

info "Password requirements:"
info "  • Auto-generated: exactly 12 characters"
info "  • User-provided: 12-64 characters"
info "  • Must include: uppercase, lowercase, numbers, and special characters"
info "Press Enter to auto-generate a secure password (recommended)"

while true; do
    printf '\n\n\n\033[3A'        # Print 3 blank lines to scroll up
    read -s -p "$(echo -e ${YELLOW}Enter root password [Press Enter to auto-generate]:${NC} )" user_password
    echo ""

    if [ -z "$user_password" ]; then
        INSTANCE_PASSWORD=$(generate_password)
        if [ -z "$INSTANCE_PASSWORD" ] || [ ${#INSTANCE_PASSWORD} -ne 12 ]; then
            error_exit "Failed to generate password"
        fi
        # Verify generated password meets requirements
        if ! validate_generated_password "$INSTANCE_PASSWORD"; then
            # Retry generation if validation fails
            INSTANCE_PASSWORD=$(generate_password)
            if ! validate_generated_password "$INSTANCE_PASSWORD"; then
                error_exit "Failed to generate valid password"
            fi
        fi
        echo ""
        print_msg "$GREEN" "✅ Password auto-generated successfully"
        echo ""
        print_msg "$CYAN" "Generated Password: ${INSTANCE_PASSWORD}"
        echo ""
        warn "⚠️  IMPORTANT: Save this password securely! It will not be shown again."
        echo ""
        log "Password auto-generated: ${INSTANCE_PASSWORD}"
        break
    else
        # Validate user-provided password length
        if [ ${#user_password} -lt 12 ]; then
            warn "Password must be at least 12 characters long. Please try again."
            continue
        fi
        if [ ${#user_password} -gt 64 ]; then
            warn "Password must be no more than 64 characters long. Please try again."
            continue
        fi
        if validate_user_password "$user_password"; then
            # Confirm password
            read -s -p "$(echo -e ${YELLOW}Confirm password:${NC} )" user_password_confirm
            echo ""

            if [ "$user_password" = "$user_password_confirm" ]; then
                INSTANCE_PASSWORD="$user_password"
                echo "Password accepted"
                log "Password provided by user (length: ${#user_password} characters)"
                break
            else
                warn "Passwords do not match. Please try again."
            fi
        else
            warn "Password does not meet requirements. Must be 12-64 characters with uppercase, lowercase, numbers, and special characters."
        fi
    fi
done

echo ""

#==============================================================================
# Let User Select SSH Public Key
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "🔑 Step 7/10: SSH Public Key (Required)"
echo "------------------------------------------------------"
log "Step 7: SSH key selection"

info "An SSH key is required for secure access to the instance"
echo ""

# Find all SSH public keys
SSH_KEYS=()
while IFS= read -r line; do
    SSH_KEYS+=("$line")
done < <(find "$HOME/.ssh" -maxdepth 1 -name "*.pub" -type f 2>/dev/null | sort)

# Display options
print_msg "$GREEN" "SSH Key Options:"
echo ""

# Show existing keys
if [ ${#SSH_KEYS[@]} -gt 0 ]; then
    for i in "${!SSH_KEYS[@]}"; do
        key_file="${SSH_KEYS[$i]}"
        key_name=$(basename "$key_file")
        key_preview=$(head -c 60 "$key_file")
        printf "${CYAN}%2d.${NC} %-30s %s...\n" "$((i+1))" "$key_name" "$key_preview"
    done
fi

# Add auto-generate option
AUTO_GEN_OPTION=$((${#SSH_KEYS[@]} + 1))

printf "${CYAN}%2d.${NC} ${YELLOW}Auto-generate new SSH key pair${NC}\n" "$AUTO_GEN_OPTION"

echo ""

while true; do
    printf '\n\n\n\033[3A'        # Print 3 blank lines to scroll up
    read -p "$(echo -e ${YELLOW}Enter SSH key option:${NC} )" key_choice

    if [[ ! "$key_choice" =~ ^[0-9]+$ ]]; then
        warn "Invalid choice. Please enter a number."
        continue
    fi

    # Use existing key
    if [ "$key_choice" -ge 1 ] && [ "$key_choice" -le ${#SSH_KEYS[@]} ]; then
        SSH_PUBLIC_KEY=$(cat "${SSH_KEYS[$((key_choice-1))]}")
        echo "Selected SSH key: $(basename "${SSH_KEYS[$((key_choice-1))]}")"
        log "Using existing SSH key: $(basename "${SSH_KEYS[$((key_choice-1))]}")"
        break
    # Auto-generate new key
    elif [ "$key_choice" -eq "$AUTO_GEN_OPTION" ]; then
        NEW_KEY_NAME="linode-${INSTANCE_LABEL}-$(date +%s)"
        NEW_KEY_PATH="$HOME/.ssh/${NEW_KEY_NAME}"

        info "Generating new SSH key pair: ${NEW_KEY_NAME}"
        ssh-keygen -t ed25519 -f "$NEW_KEY_PATH" -N "" -C "${NEW_KEY_NAME}" >/dev/null 2>&1

        if [ -f "${NEW_KEY_PATH}.pub" ]; then
            SSH_PUBLIC_KEY=$(cat "${NEW_KEY_PATH}.pub")
            success "Generated new SSH key: ${NEW_KEY_PATH}"
            info "Private key saved to: ${NEW_KEY_PATH}"
            warn "IMPORTANT: Save the private key securely!"
            log "Generated new SSH key: ${NEW_KEY_PATH}"
            break
        else
            error_exit "Failed to generate SSH key"
        fi
    else
        warn "Invalid choice. Please enter a number between 1 and ${AUTO_GEN_OPTION}"
    fi
done

echo ""

#==============================================================================
# Create Cloud-Init with Base64 Encoded Files
#==============================================================================
log "Step 8: Preparing cloud-init configuration"

# Base64 encode docker-compose.yml
if [ ! -f "${PROJECT_ROOT}/templates/docker-compose.yml" ]; then
    error_exit "templates/docker-compose.yml not found"
fi
DOCKER_COMPOSE_BASE64=$(base64 < "${PROJECT_ROOT}/templates/docker-compose.yml" | tr -d '\n')
log "Docker Compose template encoded"

# Base64 encode install.sh
if [ ! -f "${PROJECT_ROOT}/templates/install.sh" ]; then
    error_exit "templates/install.sh not found"
fi
INSTALL_SH_BASE64=$(base64 < "${PROJECT_ROOT}/templates/install.sh" | tr -d '\n')
log "Install script encoded"

# Read cloud-init template
if [ ! -f "${PROJECT_ROOT}/templates/cloud-init.yaml" ]; then
    error_exit "templates/cloud-init.yaml not found"
fi

# Create temporary cloud-init file with replacements
CLOUD_INIT_DATA=$(cat "${PROJECT_ROOT}/templates/cloud-init.yaml" | \
    sed "s|INSTANCE_LABEL_PLACEHOLDER|${INSTANCE_LABEL}|g" | \
    sed "s|DOCKER_COMPOSE_BASE64_CONTENT_PLACEHOLDER|${DOCKER_COMPOSE_BASE64}|g" | \
    sed "s|INSTALL_SH_BASE64_CONTENT_PLACEHOLDER|${INSTALL_SH_BASE64}|g")
log "Cloud-init data prepared"

#==============================================================================
# Show Confirmation Prompt
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "📝 Step 8/10: Confirmation ..."
echo "------------------------------------------------------"

info "Instance configuration:"
echo "  Region: $SELECTED_REGION"
echo "  Type: $SELECTED_TYPE"
echo "  Label: $INSTANCE_LABEL"
echo "  Image: $UBUNTU_IMAGE"
echo "  Model: $MODEL_ID"
if [ "$key_choice" -eq "$AUTO_GEN_OPTION" ]; then
    echo "  SSH Key: ${NEW_KEY_NAME} (auto-generated)"
else
    echo "  SSH Key: $(basename "${SSH_KEYS[$((key_choice-1))]}")"
fi
echo ""

# Ask for confirmation
printf '\n\n\n\033[3A'        # Print 3 blank lines to scroll up
read -p "$(echo -e ${YELLOW}Proceed with instance creation? [Y/n]:${NC} )" confirm
confirm=${confirm:-Y}

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "Instance creation cancelled by user"
    log "Instance creation cancelled by user"
    exit 0
fi
echo ""

#==============================================================================
# Create Instance via Linode API
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "🚀 Step 9/10: Creating instance ..."
echo "------------------------------------------------------"
log "Step 9: Creating instance via Linode API"

# Encode cloud-init as base64
USER_DATA_BASE64=$(echo "$CLOUD_INIT_DATA" | base64 | tr -d '\n')

# Build JSON payload
JSON_PAYLOAD=$(jq -n \
    --arg label "$INSTANCE_LABEL" \
    --arg region "$SELECTED_REGION" \
    --arg type "$SELECTED_TYPE" \
    --arg image "$UBUNTU_IMAGE" \
    --arg pass "$INSTANCE_PASSWORD" \
    --arg userdata "$USER_DATA_BASE64" \
    --arg sshkey "$SSH_PUBLIC_KEY" \
    '{label: $label, region: $region, type: $type, image: $image, root_pass: $pass,
      metadata: {user_data: $userdata}, authorized_keys: [$sshkey],
      booted: true, backups_enabled: false, private_ip: false}')

log "Sending instance creation request to Linode API"
CREATE_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "${API_BASE}/linode/instances" \
    -d "$JSON_PAYLOAD")

log "API Response received"

# Check for errors
if echo "$CREATE_RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$CREATE_RESPONSE" | jq -r '.errors[0].reason')
    log "ERROR: Failed to create instance: ${ERROR_MSG}"
    error_exit "Failed to create instance: ${ERROR_MSG}"
fi

INSTANCE_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
INSTANCE_IP=$(echo "$CREATE_RESPONSE" | jq -r '.ipv4[0]')

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
    error_exit "Failed to create instance: Invalid response"
fi

log "Instance created successfully: ID=${INSTANCE_ID}, IP=${INSTANCE_IP}"

# Save instance data with password
INSTANCE_FILE="${PROJECT_ROOT}/${INSTANCE_LABEL}.json"
echo "$CREATE_RESPONSE" | jq --arg password "$INSTANCE_PASSWORD" '. + {root_password: $password}' > "$INSTANCE_FILE"
log "Instance data saved to: ${INSTANCE_FILE}"

info "Instance created successfully, starting up..."
echo "  Instance ID: $INSTANCE_ID"
echo "  IP Address: $INSTANCE_IP"
echo "  Instance detail saved to:   $INSTANCE_FILE"
echo ""

#==============================================================================
# Wait for Instance to be Ready
#==============================================================================
echo "------------------------------------------------------"
print_msg "$BOLD" "⏳ Step 10: Monitoring Deployment ..."
echo "------------------------------------------------------"
printf '\n\n\n\033[5A'        # Print 5 blank lines to scroll up
log "Step 10: Monitoring deployment"

#------------------------------------------------------------------------------
# Phase 1: Wait for instance status to become "running" (max 3 minutes)
#------------------------------------------------------------------------------
print_msg "$YELLOW" "Waiting instance to boot up ... (this may take 2 - 3 minutes)"
START_TIME=$(date +%s)
TIMEOUT=180

while true; do
    STATUS=$(curl -s -H "Authorization: Bearer ${TOKEN}" "${API_BASE}/linode/instances/${INSTANCE_ID}" | jq -r '.status')
    [ "$STATUS" = "running" ] && break

    ELAPSED=$(($(date +%s) - START_TIME))
    [ $ELAPSED -ge $TIMEOUT ] && break

    ELAPSED_STR=$([ $ELAPSED -ge 60 ] && echo "$((ELAPSED / 60))m $((ELAPSED % 60))s" || echo "${ELAPSED}s")
    echo -ne "\r\033[K${YELLOW}Status: ${STATUS:-unknown} - Elapsed: ${ELAPSED_STR}${NC}"
    sleep 5
done

[ "$STATUS" != "running" ] && error_exit "Instance failed to reach 'running' status" true
ELAPSED=$(($(date +%s) - START_TIME))
echo -ne "\r\033[KInstance is now in running status (took ${ELAPSED}s)"
echo ""
log "Instance reached running status (took ${ELAPSED}s)"

#------------------------------------------------------------------------------
# Phase 2: Waiting for cloud-init to finish package install (max 3 minutes)
#------------------------------------------------------------------------------
print_msg "$YELLOW" "Waiting cloud-init to finish installing required packages ... (this may take 3 - 5 minutes)"
printf '\n\n\n\n\n\033[5A'        # Print 5 blank lines to scroll up
log "Waiting for cloud-init to complete"

# Start ntfy.sh JSON stream monitor
# Wait up to 180s for first message event, then continue until "Rebooting" or "Starting"
exec 3< <(curl -sN "https://ntfy.sh/${INSTANCE_LABEL}/json")

# Wait for first message event with 300s timeout
while IFS= read -t 300 -r line <&3; do
    event=$(echo "$line" | jq -r '.event // empty')
    [ "$event" = "message" ] && break
done || {
    exec 3<&-
    error_exit "Timeout: No cloud-init progress for 300 seconds" true
}

# Process first message and continue until termination keyword found
while true; do
    message=$(echo "$line" | jq -r '.message // empty')
    [ -n "$message" ] && {
        echo "$message" >&2
        echo "$message" | grep -qE "(Rebooting|Starting)" && break
    }

    IFS= read -r line <&3 || break
    [ "$(echo "$line" | jq -r '.event // empty')" = "message" ] || continue
done

exec 3<&-
echo ""
log "Cloud-init package installation completed"

#------------------------------------------------------------------------------
# Phase 3: Wait for Instance to reboot (max 2 minutes)
#------------------------------------------------------------------------------
sleep 5
printf '\n\n\n\n\n\033[5A'        # Print 5 blank lines to scroll up
START_TIME=$(date +%s)
TIMEOUT=120

log "Waiting for instance to reboot"
while true; do
    nc -z -w 3 "${INSTANCE_IP}" 22 &>/dev/null && break

    ELAPSED=$(($(date +%s) - START_TIME))
    [ $ELAPSED -ge $TIMEOUT ] && break

    ELAPSED_STR=$([ $ELAPSED -ge 60 ] && echo "$((ELAPSED / 60))m $((ELAPSED % 60))s" || echo "${ELAPSED}s")
    echo -ne "\r\033[K${YELLOW}Waiting for Instance to reboot... Elapsed: ${ELAPSED_STR}${NC}"
    sleep 2
done
echo ""

nc -z -w 3 "${INSTANCE_IP}" 22 &>/dev/null || error_exit "Instance failed to become accessible" true
ELAPSED=$(($(date +%s) - START_TIME))
echo "Instance is now running status (took ${ELAPSED}s)"
log "Instance reboot completed (took ${ELAPSED}s)"

#------------------------------------------------------------------------------
# Phase 4: Verify Containers are Running
#------------------------------------------------------------------------------

# Determine SSH key file for SSH access
if [ -n "${NEW_KEY_PATH:-}" ]; then
    SSH_KEY_FILE="$NEW_KEY_PATH"
else
    SSH_KEY_FILE="${SSH_KEYS[$((key_choice-1))]%.pub}"
fi

# Setup SSH command with options to suppress warnings
SSH_CMD="ssh -i $SSH_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes"
echo ""

# Verify containers are running
printf '\n\n\n\n\n\033[5A'        # Print 5 blank lines to scroll up
print_msg "$YELLOW" "Waiting for containers to start..."
log "Checking container status"
CONTAINER_CHECK=$($SSH_CMD "root@${INSTANCE_IP}" "docker ps --format '{{.Names}}' 2>/dev/null" || echo "")

if echo "$CONTAINER_CHECK" | grep -q "vllm" && echo "$CONTAINER_CHECK" | grep -q "open-webui"; then
    echo "Both vLLM and Open-WebUI containers are running"
    log "Containers are running: vllm, open-webui"
else
    warn "Some containers may still be starting. Check manually with: docker ps"
    log "WARNING: Some containers may not be running yet"
fi

echo ""
printf '\n\n\n\n\n\033[5A'        # Print 5 blank lines to scroll up
START_TIME=$(date +%s)
TIMEOUT=300  # 5 minutes timeout

log "Waiting for Open-WebUI health check"
while true; do
    HEALTH_STATUS=$($SSH_CMD "root@${INSTANCE_IP}" "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health 2>/dev/null" || echo "000")

    if [ "$HEALTH_STATUS" = "200" ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo -ne "\r\033[K"
        echo "Open-WebUI is ready (took ${ELAPSED}s)"
        log "Open-WebUI health check passed (took ${ELAPSED}s)"
        break
    fi

    ELAPSED=$(($(date +%s) - START_TIME))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -ne "\r\033[K"
        warn "Timeout waiting for Open-WebUI health check. It may still be starting up."
        log "WARNING: Open-WebUI health check timeout"
        break
    fi

    ELAPSED_STR=$([ $ELAPSED -ge 60 ] && echo "$((ELAPSED / 60))m $((ELAPSED % 60))s" || echo "${ELAPSED}s")
    echo -ne "\r\033[K${YELLOW}Waiting for Open-WebUI to be ready... Elapsed: ${ELAPSED_STR}${NC}"
    sleep 5
done

echo ""
printf '\n\n\n\n\n\033[5A'        # Print 5 blank lines to scroll up
START_TIME=$(date +%s)
TIMEOUT=600  # 10 minutes timeout for model loading

log "Waiting for vLLM model to load: ${MODEL_ID}"
while true; do
    MODELS_RESPONSE=$($SSH_CMD "root@${INSTANCE_IP}" "curl -s http://localhost:8000/v1/models 2>/dev/null" || echo "")

    # Check if response contains the expected model ID
    if echo "$MODELS_RESPONSE" | grep -q "\"id\":\"${MODEL_ID}\""; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo -ne "\r\033[K"
        echo "vLLM model is loaded and ready (took ${ELAPSED}s)"
        log "vLLM model loaded successfully: ${MODEL_ID} (took ${ELAPSED}s)"
        break
    fi

    ELAPSED=$(($(date +%s) - START_TIME))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -ne "\r\033[K"
        warn "Timeout waiting for vLLM model to load. Model may still be downloading."
        log "WARNING: vLLM model loading timeout"
        break
    fi

    ELAPSED_STR=$([ $ELAPSED -ge 60 ] && echo "$((ELAPSED / 60))m $((ELAPSED % 60))s" || echo "${ELAPSED}s")
    echo -ne "\r\033[K${YELLOW}Waiting for vLLM model to load... Elapsed: ${ELAPSED_STR}${NC}"
    sleep 10
done

echo ""

#==============================================================================
# Step 14: Show Access URL
#==============================================================================
log "Deployment completed successfully"
print_msg "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_msg "$BOLD" " 🎉 Setup Fully Completed !!"
print_msg "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_msg "$BOLD$GREEN" "✅ Your AI LLM instance is now running!"
echo ""
print_msg "$CYAN" "📊 Instance Details:"
echo "   Instance ID:    $INSTANCE_ID"
echo "   Instance Label: $INSTANCE_LABEL"
echo "   IP Address:     $INSTANCE_IP"
echo "   Region:         $SELECTED_REGION"
echo "   Instance Type:  $SELECTED_TYPE"
echo "   Model:          $MODEL_ID"
echo ""
print_msg "$CYAN" "🔐 Access Credentials:"
echo "   SSH:         ssh root@${INSTANCE_IP}"
if [ -n "${NEW_KEY_PATH:-}" ]; then
    echo "   SSH Key:     ${NEW_KEY_PATH}"
fi
echo "   Password:    ${INSTANCE_PASSWORD}"
echo ""
print_msg "$CYAN" "📁 Instance Data:"
echo "   Saved to:    $INSTANCE_FILE"
echo ""
print_msg "$CYAN" "📋 Deployment Log:"
echo "   Log file:    ${LOG_FILE}"
echo "   View with:   tail -f ${LOG_FILE}"
echo ""
print_msg "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_msg "$YELLOW" "💡 Next Step:"
echo "   • 🌐 Access Open-WebUI in your browser at"
print_msg "$CYAN" "      Open-WebUI:  http://${INSTANCE_IP}:3000"
echo "   • Create admin user on first login"
echo "   • vLLM model (${MODEL_ID}) is already loaded and ready"
echo "   • Start chatting with the model running on your GPU instance !!"
echo ""
echo "🚀 Enjoy your AI LLM Basic Stack on Akamai Cloud !!"
echo ""

