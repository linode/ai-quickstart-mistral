#!/usr/bin/env bash

# Enable better error handling with trap to avoid silent exits
set -euo pipefail

# Trap errors and provide debugging info
trap 'echo "Error on line $LINENO. Exit code: $?" >&2' ERR

#==============================================================================
# Linode GPU Availability Checker
#
# Checks availability and pricing for RTX4000 GPU instances across regions.
#
# Usage:
#   ./get-gpu-availability.sh           # Show formatted output
#   ./get-gpu-availability.sh --silent  # Output JSON data
#
#==============================================================================

# Silent mode flag
SILENT=false

# Parse arguments
if [ "${1:-}" = "--silent" ] || [ "${1:-}" = "-s" ]; then
    SILENT=true
fi

# Get directory of this script (with better Windows compatibility)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)" || {
    echo "Error: Failed to determine script directory" >&2
    exit 1
}

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# API base URL
readonly API_BASE="https://api.linode.com/v4"

# Get token from environment, check_linodecli_token.sh or linode_oauth.sh
get_token() {
    # Check environment variable first
    if [ -n "${LINODE_TOKEN:-}" ]; then
        echo "$LINODE_TOKEN"
        return 0
    fi

    # Try to get token from linode-cli config
    local token
    token=$("${SCRIPT_DIR}/check_linodecli_token.sh" --silent 2>/dev/null || true)

    if [ -n "$token" ]; then
        echo "$token"
        return 0
    fi

    # Fallback to OAuth
    if [ -f "${SCRIPT_DIR}/linode_oauth.sh" ]; then
        if [ "$SILENT" = true ]; then
            token=$("${SCRIPT_DIR}/linode_oauth.sh" --silent || true)
        else
            token=$("${SCRIPT_DIR}/linode_oauth.sh" || true)
        fi
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi

    return 1
}

# Fetch data from Linode API
api_call() {
    local endpoint="$1"
    local token="$2"

    curl -s -H "Authorization: Bearer ${token}" \
         -H "Content-Type: application/json" \
         "${API_BASE}${endpoint}"
}

# Main script
main() {
    if [ "$SILENT" = false ]; then
        echo -e "Fetching GPU availability information from Linode API..."
    fi

    # Get API token
    TOKEN=$(get_token)
    if [ -z "$TOKEN" ]; then
        if [ "$SILENT" = false ]; then
            echo -e "${RED}❌ Failed to get API token${NC}"
            echo "Please configure linode-cli or run linode_oauth.sh"
        fi
        exit 1
    fi
    
    # Use TMPDIR if set, otherwise /tmp (better Windows compatibility)
    TEMP_DIR="${TMPDIR:-/tmp}"

    # Fetch pages 1-4 in parallel + types + regions
    for page in 1 2 3 4; do
        api_call "/regions/availability?page_size=500&page=${page}" "$TOKEN" > "${TEMP_DIR}/avail_page_${page}.json" &
    done
    api_call "/linode/types" "$TOKEN" > "${TEMP_DIR}/types.json" &
    api_call "/regions" "$TOKEN" > "${TEMP_DIR}/regions.json" &

    # Wait for all parallel requests to complete
    wait

    # Verify temp files were created
    for file in "${TEMP_DIR}/avail_page_"{1,2,3,4}".json" "${TEMP_DIR}/types.json" "${TEMP_DIR}/regions.json"; do
        if [ ! -f "$file" ]; then
            if [ "$SILENT" = false ]; then
                echo -e "${RED}❌ Failed to fetch data from API (temp file missing: $file)${NC}" >&2
            fi
            exit 1
        fi
    done

    # Combine all availability pages efficiently with single jq call
    AVAILABILITY=$(jq -n -c '{data: [inputs.data[]] | unique}' "${TEMP_DIR}/avail_page_"{1,2,3,4}".json") || {
        if [ "$SILENT" = false ]; then
            echo -e "${RED}❌ Failed to process availability data with jq${NC}" >&2
        fi
        exit 1
    }
    TYPES=$(cat "${TEMP_DIR}/types.json")
    REGIONS_DATA=$(cat "${TEMP_DIR}/regions.json")

    # Clean up temp files
    rm -f "${TEMP_DIR}/avail_page_"{1,2,3,4}".json" "${TEMP_DIR}/types.json" "${TEMP_DIR}/regions.json"

    # Extract and sort RTX4000 instance types efficiently with jq
    RTX4000_TYPES=$(echo "$TYPES" | jq -c '
        [.data[] | select(.id | startswith("g2-gpu-rtx4000")) |
        {
            id: .id,
            label: .label,
            hourly: .price.hourly,
            monthly: .price.monthly,
            vcpus: .vcpus,
            memory: .memory,
            gpus: .gpus,
            sort_gpu: (.id | capture("a(?<gpu>[0-9]+)").gpu | tonumber),
            sort_size: (if (.id | endswith("-s")) then 1
                       elif (.id | endswith("-m")) then 2
                       elif (.id | endswith("-l")) then 3
                       elif (.id | endswith("-xl")) then 4
                       elif (.id | endswith("-hs")) then 5
                       else 9 end)
        }] | sort_by(.sort_gpu, .sort_size)
    ')

    if [ "$RTX4000_TYPES" = "[]" ]; then
        if [ "$SILENT" = false ]; then
            echo -e "${RED}❌ No RTX4000 instances found${NC}"
        fi
        exit 1
    fi

    # If silent mode, output JSON and exit
    if [ "$SILENT" = true ]; then
        # Use jq to build the entire JSON structure efficiently
        jq -n -c \
            --argjson availability "$AVAILABILITY" \
            --argjson regions "$REGIONS_DATA" \
            --argjson types "$RTX4000_TYPES" \
            '{
                instance_types: ($types | map(del(.sort_gpu, .sort_size))),
                regions: ($regions.data | sort_by(.id) | map(
                    . as $region |
                    {
                        id: $region.id,
                        label: $region.label,
                        instance_types: [
                            $availability.data[] |
                            select(.region == $region.id and .plan != null and (.plan | startswith("g2-gpu-rtx4000")) and .available == true) |
                            .plan
                        ] | unique | sort
                    }
                ) | map(select(.instance_types | length > 0)))
            }'
        return 0
    fi

    echo -e "${GREEN}=== RTX4000 GPU Instance Types ===${NC}\n"

    # Show all instance types with details (use jq to format all at once)
    echo "$RTX4000_TYPES" | jq -r '.[] |
        [.id, .label, .gpus, .vcpus, (.memory / 1024 | floor), .hourly, .monthly] | @tsv' | \
    while IFS=$'\t' read -r id label gpus vcpus memory hourly monthly; do
        printf "%-25s %-35s %2d GPU(s) %2d vCPUs %4dGB RAM - \$%5.2f/hr (\$%7.1f/mo)\n" \
            "$id" "$label" "$gpus" "$vcpus" "$memory" "$hourly" "$monthly"
    done

    echo -e "\n${GREEN}=== Regional Availability ===${NC}\n"

    # Get regions with RTX4000 availability
    AVAILABLE_REGIONS=$(echo "$AVAILABILITY" | jq -r '.data[] | select((.plan // "" | startswith("g2-gpu-rtx4000")) and .available == true) | .region' | sort -u)

    # Get plan IDs
    PLAN_IDS=$(echo "$RTX4000_TYPES" | jq -r '.[].id')

    # For each region with availability, show instance types
    while IFS= read -r region; do
        # Get region label
        REGION_LABEL=$(echo "$REGIONS_DATA" | jq -r ".data[] | select(.id == \"$region\") | .label")

        echo -e "${BLUE}${region}${NC} - ${REGION_LABEL}"

        # For each plan, check availability
        while IFS= read -r plan_id; do
            IS_AVAILABLE=$(echo "$AVAILABILITY" | jq -r ".data[] | select(.region == \"$region\" and .plan == \"$plan_id\") | .available")

            if [ "$IS_AVAILABLE" = "true" ]; then
                printf "  %-25s 🟢\n" "${plan_id}"
            else
                printf "  %-25s ❌\n" "${plan_id}"
            fi
        done <<< "$PLAN_IDS"

        echo ""
    done <<< "$AVAILABLE_REGIONS"
}

# Check dependencies (Windows-compatible detection)
check_command() {
    local cmd="$1"
    if type -p "$cmd" &> /dev/null || type -p "${cmd}.exe" &> /dev/null || \
       which "$cmd" &> /dev/null || which "${cmd}.exe" &> /dev/null || \
       command -v "$cmd" &> /dev/null || command -v "${cmd}.exe" &> /dev/null; then
        return 0
    fi
    return 1
}

if ! check_command jq; then
    echo -e "${RED}❌ jq is required but not installed${NC}" >&2
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    echo "Windows: Download from https://jqlang.github.io/jq/download/" >&2
    exit 1
fi

if ! check_command curl; then
    echo -e "${RED}❌ curl is required but not installed${NC}" >&2
    exit 1
fi

# Run main
main
