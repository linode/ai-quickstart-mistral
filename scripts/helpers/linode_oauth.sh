#!/usr/bin/env bash

set -euo pipefail

#==============================================================================
# Linode OAuth - Temporary Token Extractor
#
# Extracts a temporary OAuth token (valid for 2 hours) for use in scripts.
# Works on macOS, Linux, and Windows (Git Bash/WSL)
#
# Requirements:
#   - curl (required)
#   - Windows: PowerShell (built-in) or Python 3 (fallback)
#   - Unix/macOS/Linux: netcat (nc) or Python 3 (fallback)
#
# Usage:
#   ./linode_oauth.sh               # Extract token via OAuth
#   ./linode_oauth.sh -s, --silent  # Silent mode - suppress all informational output
#   ./linode_oauth.sh --help        # Show help
#
# Output:
#   Prints the token to stdout (can be captured: TOKEN=$(./linode_oauth.sh))
#==============================================================================

# Constants
readonly OAUTH_CLIENT_ID="5823b4627e45411d18e9"
readonly API_BASE_URL="https://api.linode.com/v4"
readonly OAUTH_LOGIN_URL="https://login.linode.com/oauth/authorize"

# Colors for output (to stderr)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default mode (can be overridden by command-line args)
SILENT_MODE=false

# Logging functions - all output to stderr
log_info() {
    if [ "${SILENT_MODE:-false}" = false ]; then
        echo -e "$*" >&2
    fi
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

log_warn() {
    if [ "${SILENT_MODE:-false}" = false ]; then
        echo -e "${YELLOW}⚠️  $*${NC}" >&2
    fi
}

# Show usage
show_usage() {
    cat >&2 <<EOF
Linode OAuth - Temporary Token Extractor

Usage:
    $0 [OPTIONS]

Options:
    -s, --silent    Silent mode - suppress all informational output
    --help          Show this help message

Description:
    Extracts a temporary OAuth token (valid for 2 hours) via browser login.
    Token is printed to stdout for capture by other scripts.

Examples:
    # Capture token in variable
    TOKEN=\$(./linode_oauth.sh)

    # Silent mode (only token output, no info messages)
    TOKEN=\$(./linode_oauth.sh --silent)

    # Use token immediately
    curl -H "Authorization: Bearer \$(./linode_oauth.sh -s)" \\
         https://api.linode.com/v4/profile

Requirements:
    - curl (required)
    - Windows: PowerShell (built-in) or Python 3 (fallback)
    - Unix/macOS/Linux: netcat (nc) or Python 3 (fallback)
    - Works on macOS, Linux, and Windows (Git Bash/WSL)

Note:
    - Token expires in 2 hours
    - Token is NOT saved to disk
    - Token is NOT exchanged for permanent token
    - For scripting use only
EOF
}

# Check dependencies
check_dependencies() {
    local missing=()

    # curl is required
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    # Check for at least one HTTP server method
    local has_server=false

    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        # Windows: PowerShell or Python
        if command -v powershell.exe &> /dev/null || command -v pwsh.exe &> /dev/null; then
            has_server=true
        elif command -v python3 &> /dev/null; then
            has_server=true
        fi
    else
        # Unix/macOS/Linux: netcat or Python
        if command -v nc &> /dev/null && nc -h 2>&1 | grep -q "\-l"; then
            has_server=true
        elif command -v python3 &> /dev/null; then
            has_server=true
        fi
    fi

    if [ "$has_server" = false ]; then
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
            missing+=("PowerShell or Python 3 (required for OAuth callback server)")
        else
            missing+=("netcat or Python 3 (required for OAuth callback server)")
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install them and try again."
        exit 1
    fi
}

# Parse JSON response (prefer jq, fallback to grep/sed)
parse_json() {
    local json="$1"
    local key="$2"

    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".${key} // empty"
    else
        # Fallback: basic grep/sed parsing
        echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*:.*"\(.*\)".*/\1/'
    fi
}

# Validate token and get username
validate_token() {
    local token="$1"
    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $token" \
        "${API_BASE_URL}/profile" 2>&1)

    http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        parse_json "$body" "username"
        return 0
    else
        log_error "Token validation failed with HTTP $http_code" >&2
        return 1
    fi
}

# Open URL in browser (cross-platform)
open_browser() {
    local url="$1"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open "$url" 2>/dev/null || true
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        # Windows (Git Bash, MSYS2, Cygwin)
        start "$url" 2>/dev/null || cmd.exe /c start "$url" 2>/dev/null || true
    elif command -v wslview &> /dev/null; then
        # WSL
        wslview "$url" 2>/dev/null || true
    elif command -v xdg-open &> /dev/null; then
        # Linux
        xdg-open "$url" 2>/dev/null || true
    else
        return 1
    fi
}

# Find an available port
find_available_port() {
    local port
    # Try shuf if available, otherwise use seq
    local port_list
    if command -v shuf &> /dev/null; then
        port_list=$(shuf -i 8000-9000 -n 20)
    else
        # Fallback for systems without shuf (Windows)
        port_list=$(seq 8000 8050)
    fi

    for port in $port_list; do
        # Check if port is available (works on Mac, Linux, and Windows/Git Bash)
        if ! nc -z localhost "$port" 2>/dev/null && ! netstat -an 2>/dev/null | grep -q ":${port} "; then
            echo "$port"
            return 0
        fi
    done
    return 1
}

# Create HTML landing page
create_landing_page() {
    local port="$1"
    cat <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Authentication Success</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 8px;
            padding: 40px;
            max-width: 500px;
            margin: 0 auto;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h2 { color: #02b159; margin-bottom: 20px; }
        .success { font-size: 48px; margin-bottom: 10px; }
        .info { color: #666; margin-top: 20px; line-height: 1.6; }
        .countdown {
            font-size: 24px;
            font-weight: bold;
            color: #02b159;
            margin-top: 15px;
        }
        .hint {
            color: #999;
            font-size: 14px;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success">✓</div>
        <h2>Authentication Successful</h2>
        <p>Token has been sent to your terminal.</p>
        <p class="info">Return to your terminal to continue.</p>
        <div class="countdown" id="countdown">Window closes in 10 seconds...</div>
        <p class="hint">Press Enter to close now</p>
    </div>
    <script>
        // Send token to server
        var r = new XMLHttpRequest();
        r.open('GET', 'http://localhost:PORT/token/' + window.location.hash.substr(1));
        r.send();

        // Countdown and auto-close
        var secondsLeft = 10;
        var countdownElement = document.getElementById('countdown');

        function updateCountdown() {
            countdownElement.textContent = 'Window closes in ' + secondsLeft + ' second' + (secondsLeft !== 1 ? 's' : '') + '...';
        }

        var countdownInterval = setInterval(function() {
            secondsLeft--;
            if (secondsLeft > 0) {
                updateCountdown();
            } else {
                clearInterval(countdownInterval);
                countdownElement.textContent = 'Closing...';
                window.close();
            }
        }, 1000);

        // Close on Enter key press
        document.addEventListener('keydown', function(event) {
            if (event.key === 'Enter') {
                clearInterval(countdownInterval);
                countdownElement.textContent = 'Closing...';
                window.close();
            }
        });

        // Focus the window so Enter key works
        window.focus();
    </script>
</body>
</html>
EOF
}

# Start server using Python
start_python_server() {
    local port="$1"
    local landing_page="$2"

    python3 - "$port" "$landing_page" <<'PYTHON_EOF'
import sys
import re
from http.server import HTTPServer, BaseHTTPRequestHandler

port = int(sys.argv[1])
landing_page = sys.argv[2]
token = None

class OAuthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global token

        if "token" in self.path:
            match = re.search(r"access_token=([^&\s]+)", self.path)
            if match:
                token = match.group(1)

        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(landing_page.encode('utf-8'))

    def log_message(self, format, *args):
        pass

server = HTTPServer(("localhost", port), OAuthHandler)

while token is None:
    server.handle_request()

print(token)
PYTHON_EOF
}

# Start server using PowerShell (Windows only)
start_powershell_server() {
    local port="$1"
    local landing_page="$2"

    # Escape single quotes in landing page for PowerShell
    local escaped_page="${landing_page//\'/\'\'}"

    # Determine PowerShell command
    local ps_cmd="powershell.exe"
    if command -v pwsh.exe &> /dev/null; then
        ps_cmd="pwsh.exe"
    fi

    # Run PowerShell HTTP listener
    "$ps_cmd" -NoProfile -Command "
        \$landingPage = '$escaped_page'
        \$listener = New-Object System.Net.HttpListener
        \$listener.Prefixes.Add('http://localhost:$port/')
        \$listener.Start()
        \$token = \$null

        while (\$token -eq \$null) {
            \$context = \$listener.GetContext()
            \$request = \$context.Request
            \$response = \$context.Response

            # Check if this is the token callback
            if (\$request.Url.PathAndQuery -match 'access_token=([^&]+)') {
                \$token = \$matches[1]
            }

            # Send landing page
            \$buffer = [System.Text.Encoding]::UTF8.GetBytes(\$landingPage)
            \$response.ContentLength64 = \$buffer.Length
            \$response.OutputStream.Write(\$buffer, 0, \$buffer.Length)
            \$response.OutputStream.Close()
        }

        \$listener.Stop()
        Write-Output \$token
    "
}

# Start server using netcat (Unix/macOS/Linux only - not Windows compatible)
start_nc_server() {
    local port="$1"
    local landing_page="$2"
    local token=""

    # Skip netcat on Windows as mkfifo is not available
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        log_error "Netcat server not supported on Windows."
        return 1
    fi

    local fifo="/tmp/linode_oauth_$$"
    mkfifo "$fifo" || return 1
    trap "rm -f $fifo" EXIT

    while [ -z "$token" ]; do
        {
            read -r request_line
            request_path=$(echo "$request_line" | cut -d' ' -f2)

            while read -r header; do
                [ "$header" = $'\r' ] && break
            done

            if [[ "$request_path" =~ /token/.*access_token=([^&[:space:]]+) ]]; then
                token="${BASH_REMATCH[1]}"
            fi

            echo -e "HTTP/1.1 200 OK\r"
            echo -e "Content-Type: text/html\r"
            echo -e "Content-Length: ${#landing_page}\r"
            echo -e "\r"
            echo -e "$landing_page"
        } < "$fifo" | nc -l -p "$port" > "$fifo" 2>/dev/null || true

        [ -n "$token" ] && break
    done

    echo "$token"
}

# Start OAuth callback server
start_oauth_server() {
    local port="$1"
    local landing_page="$2"
    local oauth_url="$3"

    landing_page="${landing_page//PORT/$port}"

    open_browser "$oauth_url" || log_warn "Please open the URL manually"

    # Windows: PowerShell first, Python fallback
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        # Git Bash on Windows: Use 'type -p' or 'which' instead of 'command -v'
        # Also check common PowerShell paths directly
        if type -p powershell.exe &> /dev/null || type -p pwsh.exe &> /dev/null || \
           which powershell.exe &> /dev/null || which pwsh.exe &> /dev/null || \
           [[ -f /c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]; then
            start_powershell_server "$port" "$landing_page"
        elif type -p python3 &> /dev/null || type -p python.exe &> /dev/null || \
             which python3 &> /dev/null || which python.exe &> /dev/null; then
            start_python_server "$port" "$landing_page"
        else
            log_error "Neither PowerShell nor Python 3 is available for OAuth callback server"
            return 1
        fi
    # Unix/macOS/Linux: netcat first, Python fallback
    else
        if command -v nc &> /dev/null && nc -h 2>&1 | grep -q "\-l"; then
            start_nc_server "$port" "$landing_page"
        elif command -v python3 &> /dev/null; then
            start_python_server "$port" "$landing_page"
        else
            log_error "Neither netcat nor Python 3 is available for OAuth callback server"
            return 1
        fi
    fi
}

# Main OAuth flow
extract_oauth_token() {
    log_info "Starting Linode OAuth authentication..."

    local port
    port=$(find_available_port)

    if [ -z "$port" ]; then
        log_error "Could not find an available port for OAuth callback"
        return 1
    fi

    local landing_page
    landing_page=$(create_landing_page "$port")

    local oauth_url="${OAUTH_LOGIN_URL}?client_id=${OAUTH_CLIENT_ID}&response_type=token&scopes=*&redirect_uri=http://localhost:${port}"

    if [ "$SILENT_MODE" = false ]; then
        echo "" >&2
        echo -e "${GREEN}Press Enter to open Linode login page and login to your linode account." >&2
        echo "" >&2
        echo -e "If browser doesn't open, visit following URL manually:${NC}" >&2
        echo "" >&2
        echo "$oauth_url" >&2
        echo "" >&2
        read -r -p "Press Enter to continue..." </dev/tty
        echo "" >&2
    fi

    log_info "Waiting for OAuth callback..."

    local token
    token=$(start_oauth_server "$port" "$landing_page" "$oauth_url")

    if [ -z "$token" ]; then
        log_error "Failed to receive OAuth token"
        return 1
    fi

    log_info "OAuth callback received"

    # Validate token
    log_info "Validating token..."
    local username
    if ! username=$(validate_token "$token"); then
        log_error "Token validation failed"
        return 1
    fi

    if [ -z "$username" ]; then
        log_error "Could not get username"
        return 1
    fi

    # Success - show info to stderr (unless silent)
    if [ "$SILENT_MODE" = false ]; then
        echo "" >&2
        echo -e "${GREEN}========================================${NC}" >&2
        echo -e "${GREEN}✅ Authentication Successful${NC}" >&2
        echo -e "${GREEN}========================================${NC}" >&2
        echo "" >&2
        echo -e "${YELLOW}⚠️  IMPORTANT:${NC}" >&2
        echo "  • This short term token expires in 2 hours" >&2
        echo "  • Token is NOT saved to disk & used only for this setup script" >&2
        echo "" >&2
        echo "User:$username" >&2
        echo "Token:$token" >&2
    fi

    # Always output token to stdout (can be captured)
    echo "$token"
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--silent)
                SILENT_MODE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    check_dependencies
    extract_oauth_token
}

main "$@"
