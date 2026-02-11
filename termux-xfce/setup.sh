#!/bin/bash

# Termux XFCE Installer (Proot-Distro)
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/scripts/utils.sh"

log_info "Starting Termux Desktop environment setup..."

# 1. Install Base Packages
log_info "Installing proot-distro and pulseaudio..."
pkg update -y
pkg upgrade -y
pkg install proot-distro pulseaudio wget -y

# 2. Install Debian
if ! proot-distro list | grep -q "debian.*installed"; then
    log_info "Installing Debian via proot-distro..."
    proot-distro install debian
else
    log_info "Debian is already installed."
fi

# 3. Copy internal script and run it
log_info "Running setup inside Debian (this will take time)..."
# We copy the script into the rootfs of the debian installation
cp "$DIR/scripts/debian_setup.sh" $PREFIX/var/lib/proot-distro/installed-rootfs/debian/tmp/setup.sh
chmod +x $PREFIX/var/lib/proot-distro/installed-rootfs/debian/tmp/setup.sh

# Execute the script inside proot
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
