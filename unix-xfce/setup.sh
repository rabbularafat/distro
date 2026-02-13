#!/bin/bash
# unix-xfce/setup.sh
# Monolithic one-command installer for Native Linux

set -e

# --- Colors & Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Utilities ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo."
        exit 1
    fi
}

get_distro() {
    if grep -qi "ubuntu" /etc/os-release; then
        echo "ubuntu"
    elif grep -qi "debian" /etc/os-release; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# --- Execution ---
check_root

clear
echo -e "${CYAN}========================================================${NC}"
echo -e "${CYAN}   🚀 NATIVE LINUX XFCE4 + XRDP INSTALLER (UNIX)     ${NC}"
echo -e "${CYAN}========================================================${NC}"
echo ""

# 1. System Update
log_info "Updating system repositories..."
apt update && apt upgrade -y

log_info "Installing core dependencies..."
apt install -y wget curl gnupg2 software-properties-common build-essential dbus-x11

# 2. XFCE4 Installation
DISTRO=$(get_distro)
log_info "Detected Distro: $DISTRO"
log_info "Installing XFCE4 Desktop Environment (this may take a while)..."
export DEBIAN_FRONTEND=noninteractive
apt install -y xfce4 xfce4-goodies

# 3. XRDP Configuration
log_info "Installing and configuring XRDP for remote access..."
apt install -y xrdp

# Add xrdp to ssl-cert group to avoid permission issues
if getent group ssl-cert >/dev/null; then
    usermod -a -G ssl-cert xrdp
fi

# Session configuration for current user
# Since we usually run as root/sudo, we should find the actual user calling sudo if possible
REAL_USER=$SUDO_USER
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(whoami)
fi

log_info "Configuring .xsession for user: $REAL_USER"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
echo "xfce4-session" > "$USER_HOME/.xsession"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xsession"

# Enable and start XRDP
systemctl enable xrdp
systemctl restart xrdp

echo ""
echo -e "${CYAN}========================================================${NC}"
echo -e "${GREEN}✅ NATIVE INSTALLATION COMPLETE!${NC}"
echo -e "${CYAN}========================================================${NC}"
echo ""
log_info "Next Steps:"
echo -e "1. You can now log into XFCE locally if you have a monitor."
echo -e "2. For remote access, use Windows 'mstsc' to connect to this PC's IP."
echo -e "3. Current User: $REAL_USER"
echo -e "4. Your IP Address: $(hostname -I | awk '{print $1}')"
echo ""
log_warn "Note: Ensure your firewall allows port 3389 (sudo ufw allow 3389)."
echo ""
