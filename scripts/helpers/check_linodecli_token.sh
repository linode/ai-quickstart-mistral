#!/usr/bin/env bash

set -euo pipefail

#==============================================================================
# Linode CLI Token Extractor
#
# Extracts API token from linode-cli configuration.
#
# Usage:
#   ./check_linodecli_token.sh           # Show status and token
#   ./check_linodecli_token.sh --silent  # Only output token (or nothing if not found)
#
#==============================================================================

# Silent mode flag
SILENT=false

# Parse arguments
if [ "${1:-}" = "--silent" ] || [ "${1:-}" = "-s" ]; then
    SILENT=true
fi

# Function to find linode-cli executable
find_linode_cli() {
    # Check if in PATH
    if command -v linode-cli &> /dev/null; then
        command -v linode-cli
        return 0
    fi

    # Check common installation locations
    local locations=(
        "$HOME/.local/bin/linode-cli"
        "/usr/local/bin/linode-cli"
        "/usr/bin/linode-cli"
    )

    # Add Windows-specific locations (Git Bash, WSL)
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        # Windows Python Scripts paths (Git Bash style)
        if [ -n "${APPDATA:-}" ]; then
            # User installation paths
            locations+=("$APPDATA/Python/Python311/Scripts/linode-cli.exe")
            locations+=("$APPDATA/Python/Python312/Scripts/linode-cli.exe")
            locations+=("$APPDATA/Python/Python313/Scripts/linode-cli.exe")
        fi
        if [ -n "${LOCALAPPDATA:-}" ]; then
            locations+=("$LOCALAPPDATA/Programs/Python/Python311/Scripts/linode-cli.exe")
            locations+=("$LOCALAPPDATA/Programs/Python/Python312/Scripts/linode-cli.exe")
            locations+=("$LOCALAPPDATA/Programs/Python/Python313/Scripts/linode-cli.exe")
        fi
        # System installation
        locations+=("/c/Python311/Scripts/linode-cli.exe")
        locations+=("/c/Python312/Scripts/linode-cli.exe")
        locations+=("/c/Python313/Scripts/linode-cli.exe")
    fi

    for loc in "${locations[@]}"; do
        if [ -x "$loc" ]; then
            echo "$loc"
            return 0
        fi
    done

    # Last resort: try via python -m (works on all platforms)
    if command -v python3 &> /dev/null; then
        if python3 -m linodecli --version &> /dev/null; then
            echo "python3 -m linodecli"
            return 0
        fi
    fi

    if command -v python &> /dev/null; then
        if python -m linodecli --version &> /dev/null; then
            echo "python -m linodecli"
            return 0
        fi
    fi

    return 1
}

# Function to find config file
find_config_file() {
    # Priority 1: Custom config path from environment
    if [ -n "${LINODE_CLI_CONFIG:-}" ]; then
        echo "$LINODE_CLI_CONFIG"
        return
    fi

    # Priority 2: Legacy location (works on all platforms)
    if [ -f "$HOME/.linode-cli" ]; then
        echo "$HOME/.linode-cli"
        return
    fi

    # Priority 3: Platform-specific config location
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        # Windows: Check %USERPROFILE%\.config\linode-cli
        local win_config="${USERPROFILE:-$HOME}/.config/linode-cli"
        if [ -f "$win_config" ]; then
            echo "$win_config"
            return
        fi
        # Fallback: Return Windows config path even if file doesn't exist
        echo "$win_config"
        return
    fi

    # Priority 4: XDG config location (Unix/Linux/macOS)
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    if [ -f "$xdg_config/linode-cli" ]; then
        echo "$xdg_config/linode-cli"
        return
    fi

    # Fallback: Return XDG path even if file doesn't exist
    echo "$xdg_config/linode-cli"
}

# Function to get value from INI file
get_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"

    awk -F '=' -v section="[$section]" -v key="$key" '
        $0 == section { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section {
            gsub(/^[ \t]+|[ \t]+$/, "", $1)
            if ($1 == key) {
                gsub(/^[ \t]+|[ \t]+$/, "", $2)
                print $2
                exit
            }
        }
    ' "$file"
}

# Find linode-cli executable
LINODE_CLI=$(find_linode_cli) || {
    if [ "$SILENT" = false ]; then
        echo "❌ linode-cli is not installed" >&2
    fi
    exit 1
}

# Helper function to run linode-cli (handles both direct executable and python -m)
run_linode_cli() {
    if [[ "$LINODE_CLI" == *"python"* ]]; then
        # Split command for python -m invocation
        $LINODE_CLI "$@"
    else
        # Direct executable
        "$LINODE_CLI" "$@"
    fi
}

if [ "$SILENT" = false ]; then
    # Get version
    VERSION=$(run_linode_cli --version 2>&1 | head -n 1 | awk '{print $2}')
    echo "✅ linode-cli is installed ( ver: $VERSION  path: $LINODE_CLI )"
fi

# Check if configured by looking for config file first
config_file=$(find_config_file)
if [ ! -f "$config_file" ]; then
    if [ "$SILENT" = false ]; then
        echo "❌ linode-cli is not configured (config file not found: $config_file)" >&2
    fi
    exit 1
fi

# Verify configuration with a quick command (with timeout to prevent hanging)
if ! timeout 5 run_linode_cli profile view &> /dev/null; then
    if [ "$SILENT" = false ]; then
        echo "❌ linode-cli configuration is invalid or incomplete" >&2
    fi
    exit 1
fi

# Check if token is in environment variable first
if [ -n "${LINODE_CLI_TOKEN:-}" ]; then
    if [ "$SILENT" = false ]; then
        echo "✅ linode-cli is configured"
        echo "Token:${LINODE_CLI_TOKEN}"
    else
        echo "${LINODE_CLI_TOKEN}"
    fi
    exit 0
fi

# Get default user
username=$(get_ini_value "$config_file" "DEFAULT" "default-user")
if [ -z "$username" ]; then
    if [ "$SILENT" = false ]; then
        echo "❌ No default user found in config" >&2
    fi
    exit 1
fi

if [ "$SILENT" = false ]; then
    echo "✅ linode-cli is configured ( user : $username )"
fi

# Extract token for the user
token=$(get_ini_value "$config_file" "$username" "token")
if [ -z "$token" ]; then
    if [ "$SILENT" = false ]; then
        echo "❌ No token found for user '$username'" >&2
    fi
    exit 1
fi

# Return the token
if [ "$SILENT" = false ]; then
    echo "Token:${token}"
else
    echo "${token}"
fi

