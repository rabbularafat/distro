#!/bin/bash

# ==============================================================================
# Shared Utilities for WSL Final XFCE Installer
# ==============================================================================

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# Automate installations (No prompts)
# NOTE: 'export' alone does NOT survive through 'sudo'.
# Always use: sudo DEBIAN_FRONTEND=noninteractive apt-get ...
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Claimation Package Configuration
log_info "Fetching latest Claimation version..."
export CLAIMATION_VERSION=$(curl -fsSL https://raw.githubusercontent.com/rabbularafat/wsmation/main/latest-version.txt | head -n 1 | tr -d '\r')
if [ -z "$CLAIMATION_VERSION" ]; then
    log_warn "Failed to fetch latest version, falling back to 1.5.7"
    export CLAIMATION_VERSION="1.5.7"
fi
log_info "Latest version: v${CLAIMATION_VERSION}"
export DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"
export DEB_FILE="/tmp/claimation.deb"

# Xvfb Configuration
export XVFB_DISPLAY=":99"
export XVFB_RESOLUTION="1280x1024x24"

# Display Mode Settings (.env)
export ENV_FILE="$HOME/.env"

# Forbidden display tools that must not run in HEADLESS mode
FORBIDDEN_TOOLS=("xrdp" "Xvnc" "vncserver" "teamviewer" "anydesk" "remotely")

load_env() {
    if [ -f "$ENV_FILE" ]; then
        # Load variables from .env, excluding comments and empty lines
        set -a
        source "$ENV_FILE" 2>/dev/null
        set +a
    fi
    # Support both CLAIM_MODE and MODE for compatibility (unify to CLAIM_MODE)
    local raw_mode="${CLAIM_MODE:-$MODE}"
    raw_mode="${raw_mode:-HEADLESS}"
    # Strip leading/trailing quotes (robustness fix)
    export CLAIM_MODE=$(echo "$raw_mode" | sed 's/^["]//;s/["]$//;s/^['\'']//;s/['\'']$//')
}

stop_forbidden_tools() {
    local tools=("$@")
    # Ensure pgrep is available
    if ! command -v pgrep >/dev/null 2>&1; then
        log_warn "pgrep not found. Skipping tool check."
        return
    fi
    for tool in "${tools[@]}"; do
        if pgrep -x "$tool" >/dev/null 2>&1; then
            log_warn "Forbidden display tool detected: $tool. Stopping..."
            sudo systemctl stop "$tool" 2>/dev/null || true
            sudo pkill -9 -x "$tool" 2>/dev/null || true
        fi
    done
}

enforce_display_mode() {
    load_env
    
    if [ "$CLAIM_MODE" = "HEADLESS" ] || [ "$CLAIM_MODE" = "headless" ]; then
        log_info "Enforcing strict HEADLESS mode..."
        
        # Stop everything in the forbidden list
        stop_forbidden_tools "${FORBIDDEN_TOOLS[@]}"
        
        # Ensure XRDP is specifically disabled via systemd
        sudo systemctl disable xrdp 2>/dev/null || true
        
        # Ensure Xvfb is running
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable xvfb 2>/dev/null || true
        systemctl --user start xvfb 2>/dev/null || true
        
        log_success "Mode set to HEADLESS. Unauthorized display tools stopped."
    elif [ "$CLAIM_MODE" = "DEVELOPMENT" ] || [ "$CLAIM_MODE" = "dev" ] || [ "$CLAIM_MODE" = "DEVELOPMENT" ]; then
        log_info "Enforcing DEVELOPMENT mode (XRDP + Xvfb allowed)..."
        
        # In DEV mode, we only allow xrdp and xvfb. 
        # Stop other forbidden tools (VNC, TeamViewer, etc.)
        local dev_forbidden=()
        for tool in "${FORBIDDEN_TOOLS[@]}"; do
            [ "$tool" != "xrdp" ] && dev_forbidden+=("$tool")
        done
        stop_forbidden_tools "${dev_forbidden[@]}"
        
        # Enable/Start authorized tools
        sudo systemctl enable xrdp 2>/dev/null || true
        sudo systemctl start xrdp 2>/dev/null || true
        
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable xvfb 2>/dev/null || true
        systemctl --user start xvfb 2>/dev/null || true
        
        log_success "Mode set to DEVELOPMENT. XRDP and Xvfb are active."
    else
        log_error "Unknown CLAIM_MODE: ${CLAIM_MODE}. Defaulting to HEADLESS enforcement."
        export CLAIM_MODE="HEADLESS"
        enforce_display_mode
    fi
}

# Claimation Credentials (from environment)
export CLAIM_USER="${CLAIM_USER:-}"
export CLAIM_PASS="${CLAIM_PASS:-}"
export CLAIM_FB="${CLAIM_FB:-}"

# Preconfigure keyboard and locale to prevent interactive prompts
preconfigure_packages() {
    echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/optionscode string ' | sudo debconf-set-selections
    echo 'tzdata tzdata/Areas select Etc' | sudo debconf-set-selections
    echo 'tzdata tzdata/Zones/Etc select UTC' | sudo debconf-set-selections
    echo 'locales locales/default_environment_locale select en_US.UTF-8' | sudo debconf-set-selections
    echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | sudo debconf-set-selections
    # Ensure procps is installed for pgrep/pkill
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y procps
}

# Logging functions
log_step() {
    echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run as root. Run as a normal user with sudo privileges."
        exit 1
    fi
}
