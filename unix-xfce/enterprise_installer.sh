#!/bin/bash

# ==============================================================================
# UNIVERSAL UNIX XFCE4 + XRDP ENTERPRISE INSTALLER
# ==============================================================================
# A professional, all-in-one script to transform Ubuntu/Debian into a desktop OS.
# Works for Real PCs, Servers, and Cloud Instances.
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

log_step() { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Verification ---
check_env() {
    log_info "Verifying environment..."
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo."
        exit 1
    fi
    if ! grep -qiE "ubuntu|debian" /etc/os-release; then
        log_warn "This script is optimized for Ubuntu/Debian. Continuing with caution..."
    fi
}

# --- Module 1: System Update ---
install_system_deps() {
    log_step "Updating System Packages"
    apt update && apt upgrade -y
    apt install -y wget curl gnupg2 software-properties-common build-essential dbus-x11
    log_success "System updated."
}

# --- Module 2: XFCE4 ---
install_xfce() {
    log_step "Installing XFCE4 Desktop Environment"
    log_info "This might take a while..."
    export DEBIAN_FRONTEND=noninteractive
    apt install -y xfce4 xfce4-goodies
    log_success "XFCE4 installed."
}

# --- Module 3: XRDP ---
install_xrdp() {
    log_step "Installing and Configuring XRDP"
    apt install -y xrdp
    
    # Session config for the user who ran the script
    REAL_USER=$SUDO_USER
    if [ -z "$REAL_USER" ]; then REAL_USER=$(whoami); fi
    
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    echo "xfce4-session" > "$USER_HOME/.xsession"
    chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xsession"
    
    # Xwrapper fix
    if [ -f /etc/X11/Xwrapper.config ]; then
        sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config || true
    fi
    
    # Service management
    systemctl enable xrdp
    systemctl restart xrdp
    log_success "XRDP configured and started."
}

# --- Final Output ---
print_summary() {
    echo -e "\n${CYAN}========================================================${NC}"
    echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
    echo -e "${CYAN}========================================================${NC}"
    
    echo -e "\n${YELLOW}🚨 NEXT STEPS 🚨${NC}"
    
    echo -e "\n1. ${WHITE}Get your IP Address:${NC}"
    echo -e "   Run: ${MAGENTA}hostname -I${NC}"
    
    echo -e "\n2. ${WHITE}Connect via RDP:${NC}"
    echo -e "   - Open Windows 'Remote Desktop Connection' (mstsc)"
    echo -e "   - IP: [Your Linux IP]"
    echo -e "   - User: $SUDO_USER"
    
    echo -e "\n3. ${WHITE}Firewall:${NC}"
    echo -e "   If the connection fails, run: ${MAGENTA}sudo ufw allow 3389/tcp${NC}"
    
    echo -e "\n${BLUE}Final Note:${NC} Your Linux Desktop is now ready for remote access."
    echo -e "${CYAN}========================================================${NC}\n"
}

# --- Main Execution ---
clear
echo -e "${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│     UNIX XFCE4 ENTERPRISE INSTALLER v1.0 (NATIVE)    │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────┘${NC}"

check_env
install_system_deps
install_xfce
install_xrdp
print_summary
