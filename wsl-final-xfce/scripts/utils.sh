#!/bin/bash
set -e

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

# Logging functions
log_step()    { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }



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

# Forbidden display tools/packages that must not exist in HEADLESS mode
# Note: Xvfb is EXEMPTED as it is the primary headless engine.
FORBIDDEN_TOOLS=("xrdp" "xrdp-sesman" "Xvnc" "vncserver" "tightvnc" "tigervnc" "vnc4server" "x11vnc" "teamviewer" "anydesk" "remotely" "rustdesk" "nxserver" "chrome-remote-desktop" "weston" "wayland" "gnome-remote-desktop" "xserver-xorg")
FORBIDDEN_PACKAGES=("xrdp" "xorgxrdp" "tigervnc-standalone-server" "tightvncserver" "vnc4server" "x11vnc" "weston" "anydesk" "teamviewer" "rustdesk" "nomachine" "chrome-remote-desktop" "xserver-xorg" "xserver-xorg-core" "wayland-protocols" "wayland-utils" "xwayland" "gnome-remote-desktop")

# CRITICAL detection regex for unauthorized display systems (Poison Pill)
# Matches xrdp, vnc, teamviewer, anydesk, rustdesk, etc.
VIOLATION_REGEX="xrdp|vnc|anydesk|teamviewer|rustdesk|nomachine|remotely|chrome-remote-desktop|weston|wayland"

load_env() {
    # Check multiple locations for .env files
    local possible_envs=(
        "/etc/claimation/mode.env"
        "/etc/claimation/.env"
        "/usr/lib/claimation/.env"
        "$HOME/.env"
        "$(pwd)/.env"
    )
    
    local found_env=""
    for env_path in "${possible_envs[@]}"; do
        if [ -f "$env_path" ]; then
            found_env="$env_path"
            # Load variables from .env robustly (strip CRLF, handle quotes, export)
            set -a
            # 1. Remove BOM
            # 2. Remove comments and empty lines
            # 3. Strip '\r' (CRLF fix)
            # 4. Convert key=value to export key="value"
            eval "$(sed 's/^\xEF\xBB\xBF//; s/^#.*//; s/^[[:space:]]*$//' "$found_env" | tr -d '\r' | sed 's/^\([^=]*\)=\(.*\)$/export \1=\2/' | sed 's/=\([^\"]*$\)/="\1"/')"
            set +a
            break
        fi
    done

    # Support both CLAIM_MODE and MODE, prioritizing CLAIM_MODE
    local raw_mode="${CLAIM_MODE:-$MODE}"
    raw_mode="${raw_mode:-HEADLESS}"
    
    # Normalize: strip quotes, strip '\r' (double check), and uppercase
    export CLAIM_MODE=$(echo "$raw_mode" | tr -d '\r' | sed 's/^["]//;s/["]$//;s/^['\'']//;s/['\'']$//' | tr '[:lower:]' '[:upper:]')
    export MODE="$CLAIM_MODE"
    
    [ -n "$found_env" ] && export ENV_FILE="$found_env"
}

stop_forbidden_tools() {
    local tools=("$@")
    # Ensure pgrep is available
    if ! command -v pgrep >/dev/null 2>&1; then
        return
    fi
    for tool in "${tools[@]}"; do
        if pgrep -fi "$tool" >/dev/null 2>&1; then
            log_warn "Forbidden display tool/process detected: $tool. Claimation is stopping it..."
            sudo systemctl stop "$tool" 2>/dev/null || true
            sudo pkill -9 -fi "$tool" 2>/dev/null || true
        fi
    done
}

purge_forbidden_packages() {
    local pkgs=("$@")
    local to_remove=()
    
    # Check if apt/dpkg is locked to avoid watchdog conflicts
    if [ -f /var/lib/dpkg/lock-frontend ]; then
        if sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
            log_warn "Apt database is locked. Skipping uninstallation check."
            return
        fi
    fi

    for pkg in "${pkgs[@]}"; do
        # Check if installed (ii) or partially installed
        if dpkg -l "$pkg" 2>/dev/null | grep -qE "^(ii|hi|ri|ui) "; then
            # Unhold to allow uninstallation
            sudo apt-mark unhold "$pkg" 2>/dev/null || true
            to_remove+=("$pkg")
        fi
    done

    if [ ${#to_remove[@]} -gt 0 ]; then
        log_warn "Forbidden display packages found: ${to_remove[*]}. Claimation is forcing uninstallation..."
        # Purge instead of remove to clean up configs
        sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "${to_remove[@]}"
        sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
        log_success "Forbidden packages purged successfully."
    fi
}

enforce_display_mode() {
    load_env
    
    # 1. Ensure Xvfb is ALWAYS installed and running in both modes
    # This is the 'Base Display' for all claimation activities.
    if ! dpkg -l xvfb 2>/dev/null | grep -q "^ii "; then
        log_info "Ensuring Xvfb is installed (Claimation base display)..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xvfb
    fi
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable xvfb 2>/dev/null || true
    systemctl --user start xvfb 2>/dev/null || true

    if [ "$CLAIM_MODE" = "HEADLESS" ]; then
        log_info "Claimation Mode [HEADLESS]: Enforcing strict display security..."
        
        local poison_pill_triggered=false
        local reason=""
        
        # 1. Check for installed packages
        if dpkg --get-selections | grep -qiE "$VIOLATION_REGEX" | grep -v "deinstall" >/dev/null 2>&1; then
            reason="Unauthorized package detected"
            poison_pill_triggered=true
        # 2. Check for running processes
        elif pgrep -fiE "$VIOLATION_REGEX" | grep -v "xvfb" >/dev/null 2>&1; then
            reason="Unauthorized process detected"
            poison_pill_triggered=true
        # 3. Check for listening ports (RDP: 3389, VNC: 5900+)
        elif command -v ss >/dev/null 2>&1 && ss -tln | grep -qE ":(3389|590[0-9]) "; then
            reason="Unauthorized listening port (3389/5900+) detected"
            poison_pill_triggered=true
        fi

        if [ "$poison_pill_triggered" = "true" ]; then
            log_error "SECURITY VIOLATION: $reason. Purging Claimation immediately."
            
            # Kill any running claimation process immediately (hard kill)
            sudo pkill -9 -f "claimation" 2>/dev/null || true
            sudo systemctl --user stop claimation-app.service 2>/dev/null || true
            
            # Check if apt is locked
            if [ -f /var/lib/dpkg/lock-frontend ] && sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
                log_warn "Apt is locked. Will retry package purge in 10s. Process is already killed."
            else
                sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "*claimation*" 2>/dev/null || true
                sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>/dev/null || true
                log_error "Claimation apps uninstalled successfully."
            fi
            return
        fi

        # Normal non-critical cleanup (if no poison pill triggered yet)
        stop_forbidden_tools "${FORBIDDEN_TOOLS[@]}"
        purge_forbidden_packages "${FORBIDDEN_PACKAGES[@]}"
        
        log_success "Mode set to HEADLESS. Only Xvfb is allowed."
    elif [ "$CLAIM_MODE" = "DEVELOPMENT" ]; then
        log_info "Claimation Mode [DEVELOPMENT]: Allowing XRDP + Xvfb..."
        
        # Ensure XRDP and Xvfb are active
        if ! dpkg-query -W -f='${Status}' xrdp 2>/dev/null | grep -q "ok installed"; then
            log_info "Installing XRDP for DEVELOPMENT mode..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp xorgxrdp
        fi
        
        # Ensure Xvfb is running
        pgrep -x Xvfb >/dev/null || systemctl --user start xvfb 2>/dev/null
        
        # Stop/Purge other forbidden tools EXCEPT xrdp components and foundational X11
        local dev_forbidden_tools=()
        for tool in "${FORBIDDEN_TOOLS[@]}"; do
            # NEVER purge Xorg, xserver, or xrdp components in DEVELOPMENT mode
            if [[ "$tool" != xrdp* && "$tool" != "xorgxrdp" && "$tool" != "Xorg" && "$tool" != "xserver-xorg"* ]]; then
                dev_forbidden_tools+=("$tool")
            fi
        done
        stop_forbidden_tools "${dev_forbidden_tools[@]}"
        
        local dev_forbidden_pkgs=()
        for pkg in "${FORBIDDEN_PACKAGES[@]}"; do
            # NEVER purge Xorg, xserver, or xrdp components in DEVELOPMENT mode
            if [[ "$pkg" != xrdp* && "$pkg" != "xorgxrdp" && "$pkg" != "xserver-xorg"* && "$pkg" != "x11-xserver-utils" ]]; then
                dev_forbidden_pkgs+=("$pkg")
            fi
        done
        purge_forbidden_packages "${dev_forbidden_pkgs[@]}"
        
        # Enable/Start XRDP
        sudo systemctl enable xrdp 2>/dev/null || true
        sudo systemctl start xrdp 2>/dev/null || true
        
        log_success "Mode set to DEVELOPMENT. RDP service is active."
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


check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run as root. Run as a normal user with sudo privileges."
        exit 1
    fi
}
