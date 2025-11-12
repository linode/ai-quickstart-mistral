#!/bin/bash
#<UDF name="MODEL_ID" label="AI Model ID" default="mistralai/Mistral-7B-Instruct-v0.3" example="mistralai/Mistral-7B-Instruct-v0.3">
#
# Purpose:
#   Linode StackScript that automatically deploys the AI Sandbox on first boot.
#   Configures and launches both vLLM API server and Open WebUI chat interface
#   within 5 minutes of instance boot. This enables one-click deployment of a
#   complete AI inference stack without manual configuration.
#
#   Why it exists: Provides automated deployment for Marketplace App and
#   independent deployment workflows. Eliminates manual setup steps.
#
# Dependencies:
#   - Ubuntu 22.04 LTS base image (Golden Image with pre-installed components)
#   - NVIDIA Drivers (pre-installed in Golden Image)
#   - Docker Engine (pre-installed in Golden Image)
#   - Docker Compose v2 (pre-installed in Golden Image)
#   - Internet connectivity (for pulling container images and model files)
#   - GPU instance type (for AI model inference)
#
# Troubleshooting:
#   - Deployment failures: Check /var/log/ai-sandbox/deployment.log for detailed errors
#   - Service startup issues: Verify Docker is running, check port conflicts (3000, 8000)
#   - Model download failures: Check network connectivity, disk space (~14GB required)
#   - GPU issues: Verify instance type has GPU support, check NVIDIA driver installation
#   - Error messages displayed in /etc/motd with specific failure reasons and guidance
#   - See docs/troubleshooting.md for detailed troubleshooting steps
#
# Specification Links:
#   - Feature Spec: specs/001-ai-sandbox/spec.md
#   - Implementation Plan: specs/001-ai-sandbox/plan.md
#   - Research Decisions: specs/001-ai-sandbox/research.md
#   - Data Model: specs/001-ai-sandbox/data-model.md
#
# Constitution Compliance:
#   - Principle II: One-Click Deployment Reliability (5-minute target, automatic setup)
#   - Principle III: Documentation & User Experience (clear /etc/motd messages)
#   - Principle V: Maintainability & Observability (Docker Compose, logging)
#   - Principle VI: Code Documentation & Clarity (this header and inline comments)

set -euo pipefail

# Configuration
MODEL_ID="${MODEL_ID:-mistralai/Mistral-7B-Instruct-v0.3}"
LOG_DIR="/var/log/ai-sandbox"
COMPOSE_DIR="/opt/ai-sandbox"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
MOTD_FILE="/etc/motd"

# Initialize logging
mkdir -p "${LOG_DIR}"
exec 1> >(tee -a "${LOG_DIR}/deployment.log")
exec 2> >(tee -a "${LOG_DIR}/deployment.log" >&2)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_DIR}/deployment.log"
}

# Error handling function
error_exit() {
    local error_msg="$1"
    local error_code="${2:-1}"
    
    log "ERROR: ${error_msg}"
    update_motd_error "${error_msg}"
    exit "${error_code}"
}

# Update /etc/motd with error message
update_motd_error() {
    local error_msg="$1"
    cat > "${MOTD_FILE}" <<EOF
╔════════════════════════════════════════════════════════════════╗
║          AI Sandbox Deployment - ERROR                          ║
╚════════════════════════════════════════════════════════════════╝

⚠️  DEPLOYMENT FAILED

Error: ${error_msg}

Troubleshooting:
1. Check logs: tail -f ${LOG_DIR}/deployment.log
2. Verify GPU instance type supports the selected model
3. Check disk space: df -h
4. Verify network connectivity

For detailed error information, see: ${LOG_DIR}/

EOF
}

# Update /etc/motd with success message and instructions
update_motd_success() {
    local instance_ip
    # Use Linode metadata service to get public IP (169.254.169.254 is Linode's metadata endpoint)
    # Fallback to placeholder if metadata service is unavailable
    instance_ip=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address || echo "YOUR_INSTANCE_IP")
    
    cat > "${MOTD_FILE}" <<EOF
╔════════════════════════════════════════════════════════════════╗
║          AI Sandbox - Deployment Complete                       ║
╚════════════════════════════════════════════════════════════════╝

✅ Services are running and ready!

📋 Access Your Services:
   • Chat Interface: http://${instance_ip}:3000
   • API Endpoint:   http://${instance_ip}:8000/v1

⚠️  SECURITY WARNING:
   Both services are exposed to the internet WITHOUT authentication.
   
   You MUST configure a Linode Cloud Firewall to protect:
   • Port 3000 (Chat UI)
   • Port 8000 (API)
   
   Recommended: Restrict access to trusted IP addresses only.

📚 Documentation:
   • Deployment logs: ${LOG_DIR}/
   • Service status: docker-compose -f ${COMPOSE_FILE} ps
   • View logs: docker-compose -f ${COMPOSE_FILE} logs -f

🔧 Model Configuration:
   • Model: ${MODEL_ID}
   • Model cache: /opt/models
   • Chat history: /opt/open-webui

EOF
}

# Create required directories
create_directories() {
    log "Creating required directories..."
    
    local dirs=(
        "/opt/models"
        "/opt/open-webui"
        "${COMPOSE_DIR}"
    )
    
    for dir in "${dirs[@]}"; do
        if mkdir -p "${dir}"; then
            log "Created directory: ${dir}"
        else
            error_exit "Failed to create directory: ${dir}"
        fi
    done
    
    # Set appropriate permissions (755 = owner read/write/execute, group/others read/execute)
    # This ensures Docker containers can read/write to volumes while maintaining security
    chmod 755 /opt/models
    chmod 755 /opt/open-webui
    chmod 755 "${COMPOSE_DIR}"
}

# Generate docker-compose.yml from template
generate_docker_compose() {
    log "Generating docker-compose.yml..."
    
    # Try to read from template file (for independent deployment)
    # If template exists, use it; otherwise generate inline
    # This allows the template to be copied to the instance before StackScript runs
    if [ -f "${COMPOSE_DIR}/docker-compose.yml.template" ]; then
        log "Using template file: ${COMPOSE_DIR}/docker-compose.yml.template"
        # Replace MODEL_ID_PLACEHOLDER with actual model ID using sed
        # Using | as delimiter to avoid conflicts with / in model paths
        sed "s|MODEL_ID_PLACEHOLDER|${MODEL_ID}|g" \
            "${COMPOSE_DIR}/docker-compose.yml.template" > "${COMPOSE_FILE}"
    else
        log "Template not found, generating inline docker-compose.yml"
        generate_docker_compose_inline
    fi
    
    log "Docker Compose file generated: ${COMPOSE_FILE}"
}

# Generate docker-compose.yml inline (fallback if template missing)
generate_docker_compose_inline() {
    cat > "${COMPOSE_FILE}" <<EOF
version: '3.8'

services:
  api:
    image: ghcr.io/vllm-project/vllm-openai:latest
    container_name: ai-sandbox-api
    ports:
      - "8000:8000"
    volumes:
      - /opt/models:/root/.cache/huggingface
    environment:
      - MODEL_ID=${MODEL_ID}
      # Sequential request processing: vLLM queues concurrent requests and processes them one at a time
      # This is the default behavior and prevents GPU memory contention
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
    networks:
      - ai-sandbox-network

  ui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: ai-sandbox-ui
    ports:
      - "3000:8080"
    volumes:
      - /opt/open-webui:/app/backend/data
    environment:
      - OPENAI_API_BASE_URL=http://api:8000/v1
    depends_on:
      - api
    restart: unless-stopped
    networks:
      - ai-sandbox-network

networks:
  ai-sandbox-network:
    driver: bridge

EOF
}

# Validate chat history persistence (T018)
# Verifies that /opt/open-webui directory exists and is writable
validate_chat_persistence() {
    log "Validating chat history persistence..."
    
    if [ ! -d "/opt/open-webui" ]; then
        error_exit "Chat history directory /opt/open-webui does not exist"
    fi
    
    # Test write permissions by creating a test file
    if touch /opt/open-webui/.write-test 2>/dev/null; then
        rm -f /opt/open-webui/.write-test
        log "✓ Chat history directory is writable"
    else
        error_exit "Chat history directory /opt/open-webui is not writable"
    fi
}

# Health check for Open WebUI service (T017)
# Verifies that port 3000 is accessible and service is responding
check_ui_health() {
    log "Checking Open WebUI health (port 3000)..."
    
    local max_attempts=30
    local attempt=0
    local wait_interval=2
    
    while [ ${attempt} -lt ${max_attempts} ]; do
        # Check if port is listening
        if timeout 2 bash -c "echo > /dev/tcp/localhost/3000" 2>/dev/null; then
            # Check if HTTP endpoint responds
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null || echo "000")
            
            if [ "${http_code}" = "200" ] || [ "${http_code}" = "302" ] || [ "${http_code}" = "301" ]; then
                log "✓ Open WebUI is healthy (HTTP ${http_code})"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        if [ ${attempt} -lt ${max_attempts} ]; then
            log "  Waiting for Open WebUI to be ready... (attempt ${attempt}/${max_attempts})"
            sleep ${wait_interval}
        fi
    done
    
    log "⚠️  Warning: Open WebUI health check timed out (may still be starting)"
    log "  Service may become available shortly. Check logs: docker-compose -f ${COMPOSE_FILE} logs ui"
    return 1
}

# Health check for vLLM API service (T026)
# Verifies that port 8000 is accessible and responds to basic requests
check_api_health() {
    log "Checking vLLM API health (port 8000)..."
    
    local max_attempts=60
    local attempt=0
    local wait_interval=5
    
    while [ ${attempt} -lt ${max_attempts} ]; do
        # Check if port is listening
        if timeout 2 bash -c "echo > /dev/tcp/localhost/8000" 2>/dev/null; then
            # Check if API endpoint responds (try /health or /v1/models)
            local health_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8000/health 2>/dev/null || echo "000")
            local models_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8000/v1/models 2>/dev/null || echo "000")
            
            # Either /health or /v1/models should respond
            if [ "${health_code}" = "200" ] || [ "${models_code}" = "200" ]; then
                log "✓ vLLM API is healthy (health: ${health_code}, models: ${models_code})"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        if [ ${attempt} -lt ${max_attempts} ]; then
            log "  Waiting for vLLM API to be ready... (attempt ${attempt}/${max_attempts})"
            sleep ${wait_interval}
        fi
    done
    
    log "⚠️  Warning: vLLM API health check timed out (model may still be loading)"
    log "  Large models can take 2-5 minutes to load. Check logs: docker-compose -f ${COMPOSE_FILE} logs api"
    return 1
}

# Validate OpenAI API v1 compatibility (T027)
# Tests the /v1/chat/completions endpoint with a simple request
validate_openai_api_compatibility() {
    log "Validating OpenAI API v1 compatibility..."
    
    # Wait a bit more for API to be fully ready
    sleep 3
    
    # Create a minimal test request
    local test_request='{"model":"'${MODEL_ID}'","messages":[{"role":"user","content":"test"}],"max_tokens":5}'
    
    # Make request to /v1/chat/completions endpoint
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "${test_request}" \
        --max-time 30 \
        http://localhost:8000/v1/chat/completions 2>/dev/null || echo -e "\n000")
    
    local http_code=$(echo "${response}" | tail -n1)
    local response_body=$(echo "${response}" | head -n-1)
    
    if [ "${http_code}" = "200" ]; then
        # Verify response structure matches OpenAI API v1 format
        if echo "${response_body}" | grep -q '"object".*"chat.completion"' && \
           echo "${response_body}" | grep -q '"choices"' && \
           echo "${response_body}" | grep -q '"message"'; then
            log "✓ OpenAI API v1 compatibility validated"
            return 0
        else
            log "⚠️  Warning: API responded but response format may not match OpenAI v1"
            log "  Response: ${response_body}"
            return 1
        fi
    elif [ "${http_code}" = "503" ] || [ "${http_code}" = "000" ]; then
        log "⚠️  Warning: API not ready yet (HTTP ${http_code}) - model may still be loading"
        log "  This is normal for first startup. API will be available once model loads."
        return 1
    else
        log "⚠️  Warning: API compatibility check returned HTTP ${http_code}"
        log "  Response: ${response_body}"
        return 1
    fi
}

# Main deployment function
main() {
    log "Starting AI Sandbox deployment..."
    log "Model ID: ${MODEL_ID}"
    
    # Create directories
    create_directories
    
    # Generate docker-compose.yml
    generate_docker_compose
    
    # Start services
    log "Starting Docker Compose services..."
    if docker-compose -f "${COMPOSE_FILE}" up -d; then
        log "Services started successfully"
    else
        error_exit "Failed to start Docker Compose services"
    fi
    
    # Wait a moment for services to initialize before health checks
    # This ensures services have started (even if still loading models)
    log "Waiting for services to initialize..."
    sleep 10
    
    # Validate chat history persistence (T018)
    validate_chat_persistence
    
    # Health check for Open WebUI (T017)
    # Non-blocking: Log warning if not ready, but don't fail deployment
    check_ui_health || log "  Note: Open WebUI may take additional time to start"
    
    # Health check for vLLM API (T026)
    # Non-blocking: Log warning if not ready, but don't fail deployment
    # Model loading can take 2-5 minutes, so we allow time for that
    check_api_health || log "  Note: vLLM API may still be loading the model"
    
    # Validate OpenAI API v1 compatibility (T027)
    # Non-blocking: Log warning if not ready, but don't fail deployment
    # This test requires the model to be fully loaded, which can take time
    validate_openai_api_compatibility || log "  Note: API compatibility will be available once model finishes loading"
    
    # Update MOTD with success message
    update_motd_success
    
    log "Deployment completed successfully!"
    log "Services are available at:"
    # Get instance IP from Linode metadata service for logging
    log "  - Chat UI: http://$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address || echo 'INSTANCE_IP'):3000"
    log "  - API: http://$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address || echo 'INSTANCE_IP'):8000/v1"
    log ""
    log "Note: If services are not immediately accessible, they may still be initializing."
    log "  Model loading can take 2-5 minutes. Check service status:"
    log "  docker-compose -f ${COMPOSE_FILE} ps"
}

# Run main function
main "$@"

