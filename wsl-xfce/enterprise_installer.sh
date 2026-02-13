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
install_system_deps() {
    log_step "Updating System Packages"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y wget curl gnupg2 dbus-x11
    log_success "System updated."
}

# --- Module 2: XFCE4 ---
install_xfce() {
    log_step "Installing XFCE4 Desktop Environment"
    log_info "This might take a while..."
    sudo apt install -y xfce4 xfce4-goodies
    log_success "XFCE4 installed."
}

# --- Module 3: XRDP ---
install_xrdp() {
    log_step "Installing and Configuring XRDP"
    sudo apt install -y xrdp
    
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
install_system_deps
install_xfce
install_xrdp
configure_wsl
print_summary
