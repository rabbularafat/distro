#!/bin/bash

# Termux XFCE Installer (Proot-Distro)
set -e

# Configuration
REPO_URL="https://raw.githubusercontent.com/rabbularafat/distro/main/termux-xfce"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

# Ensure curl is installed (needed for dependencies)
if ! command -v curl &> /dev/null; then
    echo "curl not found, installing..."
    pkg update -y && pkg install curl -y
fi

# Function to download dependency if missing
download_dependency() {
    local file=$1
    local dest=$2
    if [ ! -f "$dest" ]; then
        echo "Downloading $file..."
        mkdir -p "$(dirname "$dest")"
        curl -fsSL "$REPO_URL/$file" -o "$dest"
    fi
}

# Ensure we have utils.sh
if [ -f "$SCRIPTS_DIR/utils.sh" ]; then
    source "$SCRIPTS_DIR/utils.sh"
else
    # Fallback for curl | bash
    download_dependency "scripts/utils.sh" "/tmp/termux_utils.sh"
    source "/tmp/termux_utils.sh"
fi

log_info "Starting Termux Desktop environment setup..."

# 1. Install Base Packages
log_info "Installing required packages..."
pkg update -y
pkg upgrade -y
pkg install proot-distro pulseaudio wget curl -y

# 2. Install Debian
if ! proot-distro list | grep -q "debian.*installed"; then
    log_info "Installing Debian via proot-distro..."
    proot-distro install debian
else
    log_info "Debian is already installed."
fi

# 3. Setup Script inside Debian
log_info "Preparing Debian setup script..."
DEBIAN_TMP_SETUP="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/tmp/setup.sh"

if [ -f "$SCRIPTS_DIR/debian_setup.sh" ]; then
    cp "$SCRIPTS_DIR/debian_setup.sh" "$DEBIAN_TMP_SETUP"
else
    download_dependency "scripts/debian_setup.sh" "$DEBIAN_TMP_SETUP"
fi

chmod +x "$DEBIAN_TMP_SETUP"

# Execute the script inside proot
log_info "Running setup inside Debian (this may take several minutes)..."
proot-distro login debian -- bash /tmp/setup.sh

log_success "Termux Setup Complete!"
echo ""
log_warn "🚨 NEXT STEPS 🚨"
echo "1. Login to Debian as 'remote' user:"
echo -e "${YELLOW}   proot-distro login debian --user remote${NC}"
echo ""
echo "2. Start VNC Server (first time will ask for password):"
echo -e "${YELLOW}   vncserver -localhost -geometry 1280x720${NC}"
echo ""
echo "3. Open VNC Viewer app on Android:"
echo "   Address: ${GREEN}localhost:5901${NC}"
echo ""
