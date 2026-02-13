#!/bin/bash
# unix-xfce/setup.sh
# Universal Installer for Native Linux (with Isolated Proot option)

set -e

# --- Colors & Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# --- Core Functions ---
install_native() {
    check_root
    log_info "Starting Native XFCE + XRDP Installation..."
    
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

    if getent group ssl-cert >/dev/null; then
        usermod -a -G ssl-cert xrdp
    fi

    REAL_USER=$SUDO_USER
    if [ -z "$REAL_USER" ]; then REAL_USER=$(whoami); fi

    log_info "Configuring .xsession for user: $REAL_USER"
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    echo "xfce4-session" > "$USER_HOME/.xsession"
    chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xsession"

    systemctl enable xrdp
    systemctl restart xrdp

    echo ""
    echo -e "${GREEN}✅ NATIVE INSTALLATION COMPLETE!${NC}"
    log_info "IP Address: $(hostname -I | awk '{print $1}')"
    log_warn "Note: Ensure your firewall allows port 3389."
}

install_isolated() {
    check_root
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
