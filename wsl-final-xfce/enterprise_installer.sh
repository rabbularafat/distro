#!/bin/bash

# ==============================================================================
# WSL DEBIAN FINAL XFCE4 + XRDP + CLAIMATION ENTERPRISE INSTALLER v4.0
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

# Claimation dynamic version detection
CLAIMATION_VERSION=$(curl -fsSL https://raw.githubusercontent.com/rabbularafat/wsmation/main/latest-version.txt 2>/dev/null | tr -d '\r\n ' || echo "1.8.0")
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

# --- Deployment Configuration ---
MODE="${MODE:-PUBLIC}"
DEVICE="${DEVICE:-WSL}"

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
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gnupg2 dbus-x11 coreutils openssl xxd
    log_success "System updated."
}

# ==============================================================================
# MODULE 2: XFCE Desktop + Display Server (DEVELOPMENT mode only)
# ==============================================================================
install_gui() {
    if [ "$MODE" != "DEVELOPMENT" ]; then
        log_info "PUBLIC mode — skipping GUI installation (headless)."
        return
    fi

    log_step "Installing XFCE4 Desktop Environment"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xfce4 xfce4-goodies
    log_success "XFCE4 installed."

    log_step "Installing XRDP + Xvfb"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xrdp xvfb x11-xserver-utils xclip
    log_success "XRDP + Xvfb installed."

    # Configure .xsession for XFCE desktop session
    log_info "Configuring .xsession..."
    cat > ~/.xsession << 'XSESSION_EOF'
#!/bin/bash
xhost +local:
systemctl --user set-environment DISPLAY=$DISPLAY
systemctl --user set-environment XAUTHORITY=$XAUTHORITY
systemctl --user restart claimation-app.service 2>/dev/null || true
xfce4-session
XSESSION_EOF
    chmod +x ~/.xsession

    # Allow console/anybody to start X
    sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config 2>/dev/null || true

    # Enable and start XRDP now
    sudo systemctl enable xrdp 2>/dev/null || true
    sudo systemctl start xrdp 2>/dev/null || true
    log_success "XRDP enabled and started."
}

# ==============================================================================
# MODULE 3: Xvfb Headless Display (all modes)
# ==============================================================================
install_xvfb() {
    if [ "$MODE" = "DEVELOPMENT" ]; then
        # Already installed by install_gui()
        log_info "Xvfb already installed with XRDP in DEVELOPMENT mode."
    else
        log_step "Installing Xvfb (Headless Only)"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xvfb x11-xserver-utils xclip
    fi

    # Create Xvfb systemd user service
    log_step "Creating Xvfb systemd user service"
    mkdir -p ~/.config/systemd/user
    cat > ~/.config/systemd/user/xvfb.service << XVFB_EOF
[Unit]
Description=Xvfb Virtual Framebuffer (Display ${XVFB_DISPLAY})

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb ${XVFB_DISPLAY} -screen 0 ${XVFB_RESOLUTION} -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
XVFB_EOF

    # Override claimation-app.service to depend on xvfb
    mkdir -p ~/.config/systemd/user/claimation-app.service.d
    cat > ~/.config/systemd/user/claimation-app.service.d/override.conf << OVERRIDE_EOF
[Unit]
After=xvfb.service
Requires=xvfb.service

[Service]
Environment=DISPLAY=${XVFB_DISPLAY}
OVERRIDE_EOF

    # Enable xvfb
    mkdir -p ~/.config/systemd/user/default.target.wants
    ln -sf ~/.config/systemd/user/xvfb.service ~/.config/systemd/user/default.target.wants/xvfb.service 2>/dev/null || true

    log_success "Xvfb service configured."
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

    # 1. Architecture compatibility check
    ARCH=$(uname -m)
    log_info "Detected architecture: $ARCH"
    case "$ARCH" in
        x86_64|aarch64|armv7l) 
            log_success "Architecture $ARCH is supported."
            ;;
        *) 
            log_error "Unsupported architecture: $ARCH"
            exit 1 
            ;;
    esac

    # 2. Download and Install the .deb package
    log_info "Downloading Claimation v${CLAIMATION_VERSION}..."
    wget -q --show-progress -O "$DEB_FILE" "$DEB_URL"

    log_info "Installing Claimation package..."
    sudo dpkg -i "$DEB_FILE" || true
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y

    # 3. Verification & Diagnostics
    log_step "Running Diagnostics"
    if ! which claimation >/dev/null 2>&1; then
        log_error "FATAL: claimation binary not found after installation!"
        exit 1
    fi
    log_success "Binary verified: $(which claimation)"

    if command -v ldd >/dev/null 2>&1; then
        MISSING=$(ldd "$(which claimation)" 2>&1 | grep "not found" || true)
        if [ -n "$MISSING" ]; then
            log_warn "Missing libraries detected: $MISSING"
        else
            log_success "All library dependencies satisfied."
        fi
    fi

    # Clean up downloaded .deb
    rm -f "$DEB_FILE"

    # Apply profile configuration from installed package
    CONFIGURE_SCRIPT="/usr/lib/claimation/scripts/configure-profile.sh"
    if [ -f "$CONFIGURE_SCRIPT" ]; then
        log_step "Applying Profile Configuration"
        bash "$CONFIGURE_SCRIPT"
    else
        log_warn "Profile configuration script not found. Manual setup required."
    fi

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
    echo -e "   Then reopen your Debian terminal and ${WHITE}wait 15-30 seconds.${NC}"

    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}What happens after restart:${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Systemd starts all enabled services                   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Claimation will initialize itself (WSL/Termux)        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Auto-updater daemon runs as system service            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Mode:${NC} ${MAGENTA}${MODE}${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Device:${NC} ${MAGENTA}${DEVICE}${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

    if [ "$MODE" = "DEVELOPMENT" ]; then
        echo ""
        echo -e "${GREEN}🖥️  RDP Connection (DEVELOPMENT mode):${NC}"
        echo -e "   ${WHITE}1.${NC} Run ${MAGENTA}wsl --shutdown${NC} from PowerShell"
        echo -e "   ${WHITE}2.${NC} Reopen Debian terminal (this starts systemd + XRDP)"
        echo -e "   ${WHITE}3.${NC} Wait ${YELLOW}~15-30 seconds${NC} for XRDP to start listening"
        echo -e "   ${WHITE}4.${NC} Connect via RDP to ${CYAN}localhost:3389${NC}"
        echo -e ""
        echo -e "   ${YELLOW}Diagnostic commands (run after restart):${NC}"
        echo -e "   ${MAGENTA}sudo systemctl status xrdp${NC}        # is XRDP running?"
        echo -e "   ${MAGENTA}ss -tlnp | grep 3389${NC}              # is port 3389 open?"
        echo -e "   ${MAGENTA}journalctl -u xrdp --no-pager -n 20${NC}  # XRDP logs"
        echo -e "   ${MAGENTA}systemctl --user status claimation-app${NC}  # app status"
    fi

    echo ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
clear
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│   WSL DEBIAN FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER   │${NC}"
echo -e "${CYAN}│                       v4.0                              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

check_env
setup_automation_permissions
preconfigure_keyboard
install_system_deps
install_gui
install_xvfb
configure_wsl
install_claimation
print_summary
