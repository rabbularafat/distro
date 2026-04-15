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
export CLAIMATION_VERSION="1.5.3"
export DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"
export DEB_FILE="/tmp/claimation.deb"

# Xvfb Configuration
export XVFB_DISPLAY=":99"
export XVFB_RESOLUTION="1280x1024x24"

# Display Mode Settings (.env)
export ENV_FILE="$HOME/.env"

load_env() {
    if [ -f "$ENV_FILE" ]; then
        # Load variables from .env, excluding comments and empty lines
        # Using a more robust way to export variables from .env
        set -a
        source "$ENV_FILE"
        set +a
    fi
    # Fallback to default if not set
    export CLAIM_MODE="${CLAIM_MODE:-HEADLESS}"
}

enforce_display_mode() {
    load_env
    log_info "Enforcing display mode: ${CLAIM_MODE}"
    
    if [ "$CLAIM_MODE" = "HEADLESS" ] || [ "$CLAIM_MODE" = "headless" ]; then
        log_warn "HEADLESS mode: Stopping/Disabling XRDP and ensuring Xvfb is running..."
        sudo systemctl stop xrdp 2>/dev/null || true
        sudo systemctl disable xrdp 2>/dev/null || true
        
        # Ensure Xvfb is running as the only display server
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable xvfb 2>/dev/null || true
        systemctl --user start xvfb 2>/dev/null || true
        log_success "Mode set to HEADLESS. XRDP turned off."
    elif [ "$CLAIM_MODE" = "DEVELOPMENT" ] || [ "$CLAIM_MODE" = "dev" ]; then
        log_info "DEVELOPMENT mode: Enabling XRDP and keeping Xvfb active..."
        sudo systemctl enable xrdp 2>/dev/null || true
        sudo systemctl start xrdp 2>/dev/null || true
        
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable xvfb 2>/dev/null || true
        systemctl --user start xvfb 2>/dev/null || true
        log_success "Mode set to DEVELOPMENT. XRDP turned on."
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
