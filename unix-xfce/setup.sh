#!/bin/bash
# unix-xfce/setup.sh
# Universal Installer for Native Linux (with Isolated Proot option)

set -e

# Define the base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

# Source utilities if available locally
if [ -f "$SCRIPTS_DIR/utils.sh" ]; then
    source "$SCRIPTS_DIR/utils.sh"
else
    echo "Error: utils.sh not found in $SCRIPTS_DIR"
    exit 1
fi

check_root

# --- Core Functions ---
install_native() {
    log_info "Starting Native XFCE + XRDP Installation..."
    
    # Execute modular scripts
    bash "$SCRIPTS_DIR/01-system.sh"
    bash "$SCRIPTS_DIR/02-xfce.sh"
    bash "$SCRIPTS_DIR/03-xrdp.sh"

    echo ""
    echo -e "${GREEN}✅ NATIVE INSTALLATION COMPLETE!${NC}"
    log_info "IP Address: $(hostname -I | awk '{print $1}')"
    log_warn "Note: Ensure your firewall allows port 3389."
}

install_isolated() {
    log_info "Starting Isolated Debian (Proot) Installation..."
    
    # 1. Host Dependencies
    log_info "Installing Proot dependencies on host..."
    apt update
    apt install -y proot proot-distro tigervnc-standalone-server tigervnc-viewer

    # 2. Guest Debian Installation
    if ! proot-distro list | grep -q "debian.*installed"; then
        log_info "Installing guest Debian..."
        proot-distro install debian
    else
        log_info "Guest Debian already installed."
    fi

    # 3. Internal Setup Script
    log_info "Configuring internal Debian environment..."
    cat << 'EOF' > /tmp/internal_setup.sh
#!/bin/bash
apt update && apt upgrade -y
apt install -y xfce4 xfce4-goodies dbus-x11 tigervnc-standalone-server
mkdir -p ~/.vnc
echo "#!/bin/bash
xrdb \$HOME/.Xresources
startxfce4 &" > ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup
exit
EOF

    # Run internal setup
    proot-distro login debian -- bash /tmp/internal_setup.sh
    rm /tmp/internal_setup.sh

    # 4. Create Start Script
    REAL_USER=$SUDO_USER
    if [ -z "$REAL_USER" ]; then REAL_USER=$(whoami); fi
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    
    START_SCRIPT="$USER_HOME/start-debian-desktop.sh"
    echo "#!/bin/bash
# Start script for Isolated Debian Desktop
proot-distro login debian -- bash -c 'vncserver :1 -geometry 1280x720 -depth 24'
echo 'VNC Server started on localhost:5901'
echo 'Use a VNC Viewer to connect.'
" > "$START_SCRIPT"
    chown "$REAL_USER:$REAL_USER" "$START_SCRIPT"
    chmod +x "$START_SCRIPT"

    echo ""
    echo -e "${GREEN}✅ ISOLATED INSTALLATION COMPLETE!${NC}"
    log_info "To start your Debian desktop, run: ./start-debian-desktop.sh"
    log_info "Connect via VNC to: localhost:5901"
}

# --- Main Menu ---
clear
echo -e "${CYAN}========================================================${NC}"
echo -e "${CYAN}   🚀 UNIVERSAL LINUX XFCE4 INSTALLER (UNIX)         ${NC}"
echo -e "${CYAN}========================================================${NC}"
echo ""
echo -e "Choose installation type:"
echo -e "1) ${WHITE}Native Installation${NC} (Modifies this OS, uses XRDP)"
echo -e "2) ${WHITE}Isolated Debian (Termux Style)${NC} (Guest OS via Proot, uses VNC)"
echo ""
read -p "Enter choice (1 or 2): " CHOICE

case "$CHOICE" in
    1) install_native ;;
    2) install_isolated ;;
    *) log_error "Invalid choice. Exiting."; exit 1 ;;
esac

echo ""
echo -e "${CYAN}========================================================${NC}"
