#!/bin/bash

# ==============================================================================
# WSL DEBIAN XFCE4 + XRDP ENTERPRISE INSTALLER
# ==============================================================================
# A professional, all-in-one script to transform WSL Debian into a desktop OS.
# ==============================================================================

set -e

# --- Configuration & Styling ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Automate installations (No prompts)
# NOTE: We use 'sudo DEBIAN_FRONTEND=noninteractive' on each apt call
# because plain 'export' does NOT survive through sudo.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

log_step() { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Verification ---
check_env() {
    log_info "Verifying environment..."
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run as root. Run as a normal user with sudo privileges."
        exit 1
    fi
    if ! grep -qi "debian" /etc/os-release; then
        log_warn "This script is optimized for Debian. Continuing with caution..."
    fi
}

# --- Module 1: System Update ---
preconfigure_keyboard() {
    log_step "Preconfiguring keyboard layout (prevents interactive prompts)"
    # Preconfigure keyboard-configuration so dpkg never opens the dialog
    echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/optionscode string ' | sudo debconf-set-selections
    # Also preconfigure tzdata and locales to prevent other interactive prompts
    echo 'tzdata tzdata/Areas select Etc' | sudo debconf-set-selections
    echo 'tzdata tzdata/Zones/Etc select UTC' | sudo debconf-set-selections
    echo 'locales locales/default_environment_locale select en_US.UTF-8' | sudo debconf-set-selections
    echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | sudo debconf-set-selections
    log_success "Keyboard and locale preconfigured."
}

install_system_deps() {
    log_step "Updating System Packages"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gnupg2 dbus-x11
    log_success "System updated."
}

# --- Module 2: XFCE4 ---
install_xfce() {
    log_step "Installing XFCE4 Desktop Environment"
    log_info "This might take a while..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" xfce4 xfce4-goodies
    log_success "XFCE4 installed."
}

# --- Module 3: XRDP ---
install_xrdp() {
    log_step "Installing and Configuring XRDP"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp
    
    # Session config
    echo "xfce4-session" > ~/.xsession
    chmod +x ~/.xsession
    
    # Xwrapper fix
    sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config || true
    
    # Service management
    sudo systemctl enable xrdp
    sudo systemctl start xrdp
    log_success "XRDP configured and started."
}

# --- Module 4: WSL Optimizations ---
configure_wsl() {
    log_step "Optimizing WSL Configuration"
    if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
        log_info "Enabling Systemd support..."
        echo -e "[boot]\nsystemd=true" | sudo tee /etc/wsl.conf > /dev/null
        RESTART_REQUIRED=true
    else
        log_info "Systemd already enabled."
        RESTART_REQUIRED=false
    fi
}

# --- Final Output ---
print_summary() {
    echo -e "\n${CYAN}========================================================${NC}"
    echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
    echo -e "${CYAN}========================================================${NC}"
    
    echo -e "\n${YELLOW}🚨 NEXT STEPS 🚨${NC}"
    echo -e "1. ${WHITE}Restart WSL:${NC}"
    echo -e "   Run this in PowerShell: ${MAGENTA}wsl --shutdown${NC}"
    
    echo -e "\n2. ${WHITE}Get your IP Address:${NC}"
    echo -e "   Inside Debian, run: ${MAGENTA}ip addr | grep eth0${NC}"
    
    echo -e "\n3. ${WHITE}Connect via RDP:${NC}"
    echo -e "   - Open Windows 'Remote Desktop Connection'"
    echo -e "   - IP: [Your WSL IP]"
    echo -e "   - User: $(whoami)"
    
    echo -e "\n${BLUE}Final Note:${NC} If XRDP fails, ensure systemd is running after restart."
    echo -e "${CYAN}========================================================${NC}\n"
}

# --- Main Execution ---
clear
echo -e "${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│     WSL DEBIAN XFCE4 ENTERPRISE INSTALLER v2.0     │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────┘${NC}"

check_env
preconfigure_keyboard
install_system_deps
install_xfce
install_xrdp
configure_wsl
print_summary
