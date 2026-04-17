#!/bin/bash

# ==============================================================================
# WSL DEBIAN FINAL XFCE4 + XRDP + CLAIMATION ENTERPRISE INSTALLER v3.0
# ==============================================================================
# A professional, all-in-one script to transform WSL Debian into a desktop OS
# with automated Claimation deployment running 24/7 in the background.
#
# Usage:
#   export CLAIM_USER="your_custom_user"
#   export CLAIM_PASS="your_custom_pass"
#   export CLAIM_FB="optional_firebase_id"
#   export MODE="DEVELOPMENT" # optional: DEVELOPMENT or PUBLIC
#   curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/wsl-final-xfce/enterprise_installer.sh | bash
#
# After install: wsl --shutdown  (run from PowerShell, then reopen Debian)
# ==============================================================================

set -e

# --- Configuration & Styling ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Automate installations (No prompts)
# NOTE: We use 'sudo DEBIAN_FRONTEND=noninteractive' on each apt call
# because plain 'export' does NOT survive through sudo.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Claimation .deb download URL
CLAIMATION_VERSION="1.6.8"
DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"
DEB_FILE="/tmp/claimation.deb"

# Xvfb virtual display number (won't collide with XRDP's :10, :11, etc.)
XVFB_DISPLAY=":99"
XVFB_RESOLUTION="1280x1024x24"

# --- Logging Functions ---
log_step()    { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Claimation Configuration (from Environment Variables) ---
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"
MODE="${MODE:-PUBLIC}"
DEVICE="${DEVICE:-WSL}"

if [ -z "$CLAIM_USER" ]; then
    log_warn "CLAIM_USER not provided. Claimation will require manual setup on first run."
fi

# ==============================================================================
# MODULE 0: Automation & Permissions
# ==============================================================================
setup_automation_permissions() {
    log_step "Configuring Zero-Touch Automation Permissions"
    
    # Configure Passwordless Sudo for the current user
    # This is critical for 24/7 background operation (systemd/reboots)
    log_info "Granting passwordless sudo to $(whoami)..."
    echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$(whoami)" >/dev/null
    sudo chmod 0440 "/etc/sudoers.d/$(whoami)"
    
    # Export non-interactive frontend for all child processes
    export DEBIAN_FRONTEND=noninteractive
    log_success "Automation permissions configured."
}

# --- Verification ---
check_env() {
    log_info "Verifying environment..."
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run as root. Run as a normal user with sudo privileges."
        exit 1
    fi
    if ! grep -qi "debian" /etc/os-release 2>/dev/null; then
        log_warn "This script is optimized for Debian. Continuing with caution..."
    fi
}

# ==============================================================================
# MODULE 1: System Update & Dependencies
# ==============================================================================
preconfigure_keyboard() {
    log_step "Preconfiguring keyboard layout (prevents interactive prompts)"
    echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/optionscode string ' | sudo debconf-set-selections
    echo 'tzdata tzdata/Areas select Etc' | sudo debconf-set-selections
    echo 'tzdata tzdata/Zones/Etc select UTC' | sudo debconf-set-selections
    echo 'locales locales/default_environment_locale select en_US.UTF-8' | sudo debconf-set-selections
    echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | sudo debconf-set-selections
    log_success "Keyboard and locale preconfigured."
}

install_system_deps() {
    log_step "Updating System Packages"
    # Use -o options to prevent prompts during package upgrades
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gnupg2 dbus-x11 coreutils
    log_success "System updated."
}

# Modules 2 & 3 (GUI installation) have been moved inside the application package.
# This ensures faster setup and better security for the core concept.


# --- Password Encryption Helper ---
# Must match Laravel (PHP) and Claimation (Python) AES-256-CBC logic
encrypt_pass() {
    local pass="$1"
    
    # Check if already encrypted (Heuristic: 24+ chars, Base64 with padding)
    # This prevents triple-encryption when passed from the Dashboard.
    if [[ "$pass" =~ ^[A-Za-z0-9+/]{22,}==?$ ]]; then
        echo -n "$pass"
        return
    fi

    local secret="DistroClaimationSecretKey2024!24/7"
    # Derive 32-byte key from SHA256 of secret
    local key=$(echo -n "$secret" | openssl dgst -sha256 -binary | xxd -p -c 32)
    local iv="00000000000000000000000000000000"
    echo -n "$pass" | openssl enc -aes-256-cbc -K "$key" -iv "$iv" -base64 -A
}

# ==============================================================================
# MODULE 4: WSL Optimizations
# ==============================================================================
configure_wsl() {
    log_step "Optimizing WSL Configuration"

    # Enable Systemd (required for services to persist)
    if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
        log_info "Enabling Systemd support..."
        echo -e "[boot]\nsystemd=true" | sudo tee /etc/wsl.conf > /dev/null
        RESTART_REQUIRED=true
    else
        log_info "Systemd already enabled."
        RESTART_REQUIRED=false
    fi
}

# ==============================================================================
# MODULE 5: Claimation Installation & Automation
# ==============================================================================
install_claimation() {
    log_step "Installing and Automating Claimation"

    # 1. Download and Install the .deb package
    log_info "Downloading Claimation v${CLAIMATION_VERSION}..."
    wget -q --show-progress -O "$DEB_FILE" "$DEB_URL"

    log_info "Installing Claimation package..."
    sudo dpkg -i "$DEB_FILE" || true
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y

    # Store environment configuration for the app
    log_step "Persisting application configuration"
    sudo mkdir -p /etc/claimation
    cat << EOF | sudo tee /etc/claimation/config.env > /dev/null
# Environment configuration generated by installer
MODE="${MODE}"
DEVICE="${DEVICE}"
CLAIM_USER="${CLAIM_USER}"
EOF

    # Clean up downloaded .deb
    rm -f "$DEB_FILE"

    # 1b. Apply Hotfix to installed app.py (Solve Permission/Status issues)
    # ---------------------------------------------------------------
    log_info "Applying automated hotfixes to installed Claimation code..."
    APP_PY="/usr/lib/claimation/claimation/app.py"

    if [ -f "$APP_PY" ]; then
        # Fix Status Path Logic (check for write access instead of just existence)
        sudo sed -i 's/if os.geteuid() == 0 or os.path.exists(STATUS_DIR):/if os.path.exists(STATUS_DIR) and os.access(STATUS_DIR, os.W_OK):/' "$APP_PY"
        
        # Fix startup sync fallback (remove the fallback to read-only source path)
        sudo sed -i 's/initial_ext_path = get_extension_source_path()/initial_ext_path = None/' "$APP_PY"
        
        log_success "Hotfixes applied successfully."
    else
        log_warn "Could not find app.py at $APP_PY. Skipping hotfix."
    fi

    # 2. Pre-configure Claimation profile (BYPASS interactive setup)
    # ---------------------------------------------------------------
    # How it works (from app.py get_this_device_name()):
    #   - Claimation checks ~/.config/chromium-browser/ZxcvbnPkData/
    #   - If ANY subfolder exists → it uses that folder name as the device
    #   - It reads firebase_id.txt from inside that folder
    #   - The interactive username/password prompt is SKIPPED entirely
    # ---------------------------------------------------------------
    if [ -n "$CLAIM_USER" ]; then
        log_info "Pre-configuring Claimation profile for '${CLAIM_USER}'..."
        PROFILE_DIR="$HOME/.config/chromium-browser/ZxcvbnPkData/$CLAIM_USER"
        mkdir -p "$PROFILE_DIR"

        # Store Firebase ID if provided
        if [ -n "$CLAIM_FB" ]; then
            echo "$CLAIM_FB" > "$PROFILE_DIR/firebase_id.txt"
            log_info "Firebase ID stored."
        fi

        if [ -n "$CLAIM_PASS" ]; then
            encrypt_pass "$CLAIM_PASS" > "$PROFILE_DIR/claim_pass.txt"
        fi

        log_success "Profile pre-configured. Interactive setup will be bypassed."
    else
        log_warn "No CLAIM_USER set. You'll need to run 'claimation run' manually for first-time setup."
    fi

    # 3. FINAL XFCE Autostart (Desktop session fallback)
    mkdir -p ~/.config/autostart
    cat > ~/.config/autostart/claimation.desktop << 'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=Claimation
Exec=claimation run
Icon=utilities-terminal
Terminal=false
X-GNOME-Autostart-enabled=true
AUTOSTART_EOF

    # 4. Enable lingering (runs user services even when not logged in)
    log_info "Enabling user lingering for 24/7 operation..."
    sudo loginctl enable-linger "$(whoami)" 2>/dev/null || true

    # 5. Pre-enable services
    # (systemd might not be running yet — it starts after wsl --shutdown)
    mkdir -p ~/.config/systemd/user/default.target.wants
    
    # User-level app service
    ln -sf /usr/lib/systemd/user/claimation-app.service \
        ~/.config/systemd/user/default.target.wants/claimation-app.service 2>/dev/null || true
    
    # System-level updater service (requires sudo)
    sudo systemctl enable claimation-updater.service 2>/dev/null || true

    log_success "Claimation installed and automated for 24/7 background operation."
}

# ==============================================================================
# FINAL OUTPUT
# ==============================================================================
print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}✅ INSTALLATION COMPLETE!${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"

    echo ""
    echo -e "${YELLOW}🚨 REQUIRED: Restart WSL once to activate systemd${NC}"
    echo -e "   Run this in ${WHITE}Windows PowerShell${NC}:"
    echo -e "   ${MAGENTA}wsl --shutdown${NC}"
    echo -e "   Then reopen your Debian terminal."

    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}What happens after restart:${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Claimation will initialize itself (WSL/Termux)        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Security Monitor active (instantly punishes RDP/VNC)  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Auto-updater daemon runs as system service            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Mode:${NC} ${MAGENTA}${MODE}${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Device:${NC} ${MAGENTA}${DEVICE}${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

    if [ -n "$CLAIM_USER" ]; then
        echo ""
        echo -e "  ${GREEN}✅ Claimation Profile:${NC} $CLAIM_USER (auto-configured)"
    fi
    echo ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
clear
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│   WSL DEBIAN FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER   │${NC}"
echo -e "${CYAN}│                       v3.0                              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

check_env
setup_automation_permissions
preconfigure_keyboard
install_system_deps
configure_wsl
install_claimation
print_summary
