# Non-Interactive Mode Design

This document outlines the proposed changes to enable non-interactive operation of the deployment script for CI/CD and automation use cases.

## Overview

The current `deploy.sh` script is designed for interactive use with prompts for user input. Non-interactive mode would allow the script to run without user interaction, using environment variables, command-line arguments, or sensible defaults.

## Use Cases

- **CI/CD Pipelines**: Automated deployments in GitHub Actions, GitLab CI, etc.
- **Infrastructure as Code**: Integration with Terraform, Ansible, or similar tools
- **Scheduled Deployments**: Automated instance creation on schedules
- **Testing**: Automated testing of deployment workflows
- **Bulk Deployments**: Creating multiple instances programmatically

## Proposed Implementation

### 1. Environment Variables

All configuration options should be available via environment variables:

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `LINODE_TOKEN` | Linode API token | Yes* | None |
| `LINODE_REGION` | Region ID (e.g., `us-ord`) | No | First available |
| `LINODE_TYPE` | Instance type (e.g., `g2-gpu-rtx4000a1-s`) | No | First available |
| `LINODE_LABEL` | Instance label | No | `ai-quickstart-mistral-$(date +%s)` |
| `LINODE_PASSWORD` | Root password | No | Auto-generated |
| `LINODE_SSH_KEY` | Path to SSH public key file | No | Auto-generated |
| `LINODE_SSH_KEY_CONTENT` | SSH public key content (alternative to file path) | No | None |
| `MODEL_ID` | Model identifier | No | `mistralai/Mistral-7B-Instruct-v0.3` |
| `NON_INTERACTIVE` | Enable non-interactive mode | No | Auto-detected |
| `UBUNTU_IMAGE` | Ubuntu image to use | No | `linode/ubuntu24.04` |
| `SKIP_HEALTH_CHECKS` | Skip health checks after deployment | No | `false` |
| `TIMEOUT_INSTANCE_BOOT` | Timeout for instance boot (seconds) | No | `180` |
| `TIMEOUT_CLOUD_INIT` | Timeout for cloud-init (seconds) | No | `300` |
| `TIMEOUT_REBOOT` | Timeout for instance reboot (seconds) | No | `120` |
| `TIMEOUT_OPEN_WEBUI` | Timeout for Open-WebUI health check (seconds) | No | `300` |
| `TIMEOUT_MODEL_LOAD` | Timeout for model loading (seconds) | No | `600` |

*Required if not using linode-cli or OAuth

### 2. Command-Line Arguments

Support command-line arguments for all options:

```bash
./scripts/deploy.sh \
  --region us-ord \
  --type g2-gpu-rtx4000a1-s \
  --label my-instance \
  --password "MySecurePass123!" \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --model mistralai/Mistral-7B-Instruct-v0.3 \
  --non-interactive \
  --skip-health-checks
```

**Argument Reference**:

| Argument | Short | Description | Environment Variable |
|----------|-------|-------------|---------------------|
| `--region` | `-r` | Region ID | `LINODE_REGION` |
| `--type` | `-t` | Instance type | `LINODE_TYPE` |
| `--label` | `-l` | Instance label | `LINODE_LABEL` |
| `--password` | `-p` | Root password | `LINODE_PASSWORD` |
| `--ssh-key` | `-k` | SSH key file path | `LINODE_SSH_KEY` |
| `--ssh-key-content` | | SSH key content | `LINODE_SSH_KEY_CONTENT` |
| `--model` | `-m` | Model ID | `MODEL_ID` |
| `--non-interactive` | `-y` | Force non-interactive mode | `NON_INTERACTIVE` |
| `--skip-health-checks` | | Skip health checks | `SKIP_HEALTH_CHECKS` |
| `--timeout-instance-boot` | | Instance boot timeout | `TIMEOUT_INSTANCE_BOOT` |
| `--timeout-cloud-init` | | Cloud-init timeout | `TIMEOUT_CLOUD_INIT` |
| `--timeout-reboot` | | Reboot timeout | `TIMEOUT_REBOOT` |
| `--timeout-open-webui` | | Open-WebUI timeout | `TIMEOUT_OPEN_WEBUI` |
| `--timeout-model-load` | | Model load timeout | `TIMEOUT_MODEL_LOAD` |
| `--help` | `-h` | Show help message | N/A |
| `--version` | `-v` | Show version | N/A |

### 3. Non-Interactive Detection

The script should automatically detect non-interactive mode:

```bash
# Check if running in non-interactive environment
is_non_interactive() {
    # Explicit flag
    [ "${NON_INTERACTIVE:-false}" = "true" ] && return 0
    
    # Command-line flag
    [[ " $* " =~ " --non-interactive " ]] && return 0
    [[ " $* " =~ " -y " ]] && return 0
    
    # Auto-detect: no TTY
    [ ! -t 0 ] || [ ! -t 1 ] && return 0
    
    return 1
}
```

### 4. Default Values

When running non-interactively, use sensible defaults:

- **Region**: First available region with GPU instances
- **Instance Type**: First available instance type (or smallest by default)
- **Label**: `ai-quickstart-mistral-$(date +%s)`
- **Password**: Auto-generated (meets Linode requirements)
- **SSH Key**: Auto-generated if not provided
- **Model**: `mistralai/Mistral-7B-Instruct-v0.3`

### 5. Error Handling

Non-interactive mode should:

- **Fail fast**: Exit immediately on missing required parameters
- **Clear errors**: Provide actionable error messages
- **Exit codes**: Return appropriate exit codes for CI/CD:
  - `0`: Success
  - `1`: General error
  - `2`: Invalid arguments
  - `3`: Authentication failure
  - `4`: Instance creation failure
  - `5`: Deployment timeout
  - `6`: Health check failure
- **No prompts**: Never wait for user input
- **Logging**: All output goes to log file (stdout/stderr still available)

### 6. Implementation Changes

#### 6.1 Argument Parsing

Add argument parsing function:

```bash
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --region|-r)
                LINODE_REGION="$2"
                shift 2
                ;;
            --type|-t)
                LINODE_TYPE="$2"
                shift 2
                ;;
            --label|-l)
                LINODE_LABEL="$2"
                shift 2
                ;;
            --password|-p)
                LINODE_PASSWORD="$2"
                shift 2
                ;;
            --ssh-key|-k)
                LINODE_SSH_KEY="$2"
                shift 2
                ;;
            --model|-m)
                MODEL_ID="$2"
                shift 2
                ;;
            --non-interactive|-y)
                NON_INTERACTIVE=true
                shift
                ;;
            --skip-health-checks)
                SKIP_HEALTH_CHECKS=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done
}
```

#### 6.2 Non-Interactive Flow

Modify the main flow to skip prompts:

```bash
if is_non_interactive "$@"; then
    # Use environment variables or defaults
    SELECTED_REGION="${LINODE_REGION:-$(get_first_available_region)}"
    SELECTED_TYPE="${LINODE_TYPE:-$(get_first_available_type)}"
    INSTANCE_LABEL="${LINODE_LABEL:-ai-quickstart-mistral-$(date +%s)}"
    INSTANCE_PASSWORD="${LINODE_PASSWORD:-$(generate_password)}"
    SSH_PUBLIC_KEY="${LINODE_SSH_KEY_CONTENT:-$(get_ssh_key_content)}"
    MODEL_ID="${MODEL_ID:-mistralai/Mistral-7B-Instruct-v0.3}"
    
    log "Non-interactive mode: Using defaults or environment variables"
    log "Region: ${SELECTED_REGION}, Type: ${SELECTED_TYPE}, Label: ${INSTANCE_LABEL}"
else
    # Interactive prompts (existing code)
    SELECTED_REGION=$(prompt_region)
    SELECTED_TYPE=$(prompt_instance_size)
    # ... etc
fi
```

#### 6.3 SSH Key Handling

```bash
get_ssh_key_content() {
    # Priority 1: Content from environment
    if [ -n "${LINODE_SSH_KEY_CONTENT:-}" ]; then
        echo "${LINODE_SSH_KEY_CONTENT}"
        return 0
    fi
    
    # Priority 2: File path from environment
    if [ -n "${LINODE_SSH_KEY:-}" ] && [ -f "${LINODE_SSH_KEY}" ]; then
        cat "${LINODE_SSH_KEY}"
        return 0
    fi
    
    # Priority 3: Auto-generate
    if [ "${NON_INTERACTIVE:-false}" = "true" ]; then
        generate_ssh_key
        return 0
    fi
    
    # Priority 4: Interactive prompt (existing code)
    prompt_ssh_key
}
```

#### 6.4 Health Checks

Make health checks optional:

```bash
if [ "${SKIP_HEALTH_CHECKS:-false}" != "true" ]; then
    # Run health checks (existing code)
    check_open_webui_health
    check_vllm_model_loading
else
    log "Skipping health checks (SKIP_HEALTH_CHECKS=true)"
    warn "Health checks skipped. Verify services manually."
fi
```

### 7. Example Usage

#### 7.1 Environment Variables

```bash
export LINODE_TOKEN="your-token-here"
export LINODE_REGION="us-ord"
export LINODE_TYPE="g2-gpu-rtx4000a1-s"
export LINODE_LABEL="my-test-instance"
export NON_INTERACTIVE=true

./scripts/deploy.sh
```

#### 7.2 Command-Line Arguments

```bash
./scripts/deploy.sh \
  --region us-ord \
  --type g2-gpu-rtx4000a1-s \
  --label my-test-instance \
  --non-interactive
```

#### 7.3 CI/CD Example (GitHub Actions)

```yaml
name: Deploy AI Instance

on:
  workflow_dispatch:
    inputs:
      region:
        description: 'Region ID'
        required: true
        default: 'us-ord'
      instance_type:
        description: 'Instance Type'
        required: true
        default: 'g2-gpu-rtx4000a1-s'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy Instance
        env:
          LINODE_TOKEN: ${{ secrets.LINODE_TOKEN }}
          LINODE_REGION: ${{ github.event.inputs.region }}
          LINODE_TYPE: ${{ github.event.inputs.instance_type }}
          NON_INTERACTIVE: true
        run: |
          chmod +x scripts/deploy.sh
          ./scripts/deploy.sh
```

#### 7.4 Minimal Example (All Defaults)

```bash
export LINODE_TOKEN="your-token-here"
export NON_INTERACTIVE=true

./scripts/deploy.sh
# Uses first available region, first available type, auto-generated label/password/SSH key
```

### 8. Output Format

In non-interactive mode, output should be:

- **Structured**: JSON or key-value pairs for parsing
- **Logging**: All output to log file
- **Summary**: Final summary with instance details
- **Exit codes**: Appropriate exit codes for CI/CD

Example output format option:

```bash
if [ "${NON_INTERACTIVE:-false}" = "true" ] && [ "${OUTPUT_FORMAT:-}" = "json" ]; then
    echo "{\"instance_id\":\"${INSTANCE_ID}\",\"ip\":\"${INSTANCE_IP}\",\"label\":\"${INSTANCE_LABEL}\"}"
else
    # Human-readable output (existing)
fi
```

### 9. Validation

Before proceeding, validate:

- Required parameters are present
- Region is valid and has GPU availability
- Instance type is valid and available in selected region
- Password meets requirements (if provided)
- SSH key is valid (if provided)
- Model ID is accessible (optional check)

### 10. Testing

Test scenarios:

1. **Minimal**: Only token provided, all defaults used
2. **Full**: All parameters provided via environment variables
3. **Mixed**: Some via environment, some via command-line
4. **Defaults**: Verify default selection logic
5. **Error handling**: Missing required parameters, invalid values
6. **CI/CD**: Test in actual CI/CD environment

### 11. Backward Compatibility

- Interactive mode remains the default
- All existing functionality preserved
- Non-interactive mode is opt-in
- No breaking changes to existing usage

### 12. Documentation Updates

Update documentation to include:

- Non-interactive mode usage examples
- Environment variable reference
- Command-line argument reference
- CI/CD integration examples
- Exit code reference
- Error handling guide

## Implementation Priority

1. **Phase 1**: Environment variable support, auto-detection, basic defaults
2. **Phase 2**: Command-line arguments, validation, error handling
3. **Phase 3**: Advanced features (timeouts, output formats), CI/CD examples
4. **Phase 4**: Testing, documentation, refinement

## Notes

- This is a design document - implementation details may vary
- Some features may be implemented incrementally
- User feedback will guide prioritization
- Consider adding `--dry-run` mode for testing without creating instances

