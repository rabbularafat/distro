#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX11 FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER v3.2 (Pure Enterprise)
# ==============================================================================
# A professional, all-in-one script to transform Termux into a desktop OS
# with automated Claimation deployment running 24/7 in the background.
#
# Usage:
#   export CLAIM_USER="your_custom_user"
#   export CLAIM_PASS="your_custom_pass"
#   export CLAIM_FB="optional_firebase_id"
#   export MODE="DEVELOPMENT" # optional: DEVELOPMENT or PUBLIC
#   curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-final-xfce/install.sh | bash
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

# Claimation .deb download URL
CLAIMATION_VERSION="1.6.9"
DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"
DEB_FILE="/tmp/claimation.deb"

# --- Logging Functions ---
log_step()    { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Claimation Configuration ---
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"
MODE="${MODE:-PUBLIC}"
DEVICE="${DEVICE:-TERMUX}"

# --- Verification ---
check_env() {
    log_info "Verifying environment..."
    if [ ! -d "/data/data/com.termux" ]; then
        log_error "This script MUST be run inside the Termux app on Android."
        exit 1
    fi
}

# ==============================================================================
# MODULE 1: Host Environment (Termux)
# ==============================================================================
setup_termux() {
    log_step "Updating Termux Base"
    termux-wake-lock || true
    pkg update -y && pkg upgrade -y
    pkg install x11-repo -y
    pkg install termux-x11-nightly proot-distro pulseaudio curl wget x11-xserver-utils openssl xxd -y
}

# ==============================================================================
# MODULE 2: Debian Guest Installation
# ==============================================================================
setup_debian() {
    log_step "Installing Debian (proot-distro)"
    if ! proot-distro list | grep -q "debian.*installed"; then
        proot-distro install debian
    fi
}

# ==============================================================================
# MODULE 3: Guest Configuration (Self-Contained)
# ==============================================================================
configure_guest() {
    log_step "Configuring Internal Debian Environment"
    
    DEBIAN_PATH="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
    DEBIAN_TMP_SETUP="$DEBIAN_PATH/tmp/setup_guest.sh"
    
    # Create the guest setup script internally
    # NOTE: GUI Components (XFCE, etc.) are NOT installed here.
    # The application itself will trigger GUI setup if MODE="DEVELOPMENT".
    cat << GUEST_EOF > "$DEBIAN_TMP_SETUP"
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Colors
BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
log_step() { echo -e "\${CYAN}[GUEST-STEP]\${NC} \$1"; }

log_step "Updating Repositories"
apt update && apt upgrade -y
apt install -y sudo nano wget curl gnupg2 ca-certificates dbus-x11 x11-xserver-utils xvfb xclip chromium

log_step "Configuring Chromium"
mkdir -p /etc/chromium.d
echo 'export CHROMIUM_FLAGS="\$CHROMIUM_FLAGS --no-sandbox"' > /etc/chromium.d/proot-flags

log_step "Installing Claimation v${CLAIMATION_VERSION}"
wget -q -O /tmp/claimation.deb "${DEB_URL}"
if ! pidof systemd > /dev/null 2>&1; then
    echo -e "#!/bin/bash\nexit 0" > /usr/bin/systemctl && chmod +x /usr/bin/systemctl
fi
dpkg -i /tmp/claimation.deb || apt install -f -y
rm -f /tmp/claimation.deb

log_step "Persisting Configuration"
mkdir -p /etc/claimation
cat << EOF_CONF > /etc/claimation/config.env
MODE="${MODE}"
DEVICE="${DEVICE}"
CLAIM_USER="${CLAIM_USER}"
EOF_CONF

# Apply Hotfixes
APP_PY="/usr/lib/claimation/claimation/app.py"
if [ -f "\$APP_PY" ]; then
    sed -i 's/or config.get/or config_env.get/g' "\$APP_PY"
    sed -i 's/if os.geteuid() == 0 or os.path.exists(STATUS_DIR):/if os.path.exists(STATUS_DIR) and os.access(STATUS_DIR, os.W_OK):/' "\$APP_PY"
fi

# Pre-configure Profile
if [ -n "$CLAIM_USER" ]; then
    PROFILE_DIR="/root/.config/chromium-browser/ZxcvbnPkData/$CLAIM_USER"
    mkdir -p "\$PROFILE_DIR"
    [ -n "$CLAIM_FB" ] && echo "$CLAIM_FB" > "\$PROFILE_DIR/firebase_id.txt"
    if [ -n "$CLAIM_PASS" ]; then
        key=\$(echo -n "DistroClaimationSecretKey2024!24/7" | openssl dgst -sha256 -binary | xxd -p -c 32)
        echo -n "$CLAIM_PASS" | openssl enc -aes-256-cbc -K "\$key" -iv "00000000000000000000000000000000" -base64 -A > "\$PROFILE_DIR/claim_pass.txt"
    fi
fi

log_step "Creating Watchdog"
cat <<'WATCHDOG_EOF' > /usr/local/bin/claimation-watchdog
#!/bin/bash
PIDFILE="/tmp/claimation-watchdog.pid"
[ -f "\$PIDFILE" ] && kill -0 \$(cat \$PIDFILE) 2>/dev/null && exit 0
echo \$\$ > "\$PIDFILE"
while true; do
    pgrep -f "claimation.daemon" >/dev/null || claimation-daemon run >/dev/null 2>&1 &
    pgrep -f "claimation run" >/dev/null || (export DISPLAY=:99; claimation run --skip-update-check >/dev/null 2>&1 &)
    sleep 60
done
WATCHDOG_EOF
chmod +x /usr/local/bin/claimation-watchdog
grep -q "claimation-watchdog" /root/.bashrc || echo "(nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &)" >> /root/.bashrc
GUEST_EOF

    chmod +x "$DEBIAN_TMP_SETUP"
    proot-distro login debian -- bash /tmp/setup_guest.sh
}

# ==============================================================================
# MODULE 4: Persistence (Termux)
# ==============================================================================
setup_persistence() {
    log_step "Configuring Host Persistence"
    
    # Start-XFCE
    cat <<'EOF' > "$HOME/start-xfce.sh"
#!/data/data/com.termux/files/usr/bin/bash
pkill -f termux-x11 2>/dev/null; pkill -f Xwayland 2>/dev/null
termux-x11 :0 >/dev/null 2>&1 &
pulseaudio --start --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
termux-wake-lock; sleep 2
export DISPLAY=:0; export PULSE_SERVER=127.0.0.1; export XDG_RUNTIME_DIR=$TMPDIR
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; startxfce4"
EOF
    chmod +x "$HOME/start-xfce.sh"
    
    # Bashrc aliases
    grep -q "alias start-xfce" ~/.bashrc || echo "alias start-xfce='bash ~/start-xfce.sh'" >> ~/.bashrc
    grep -q "claimation-autostart" ~/.bashrc || cat >> ~/.bashrc << 'EOF'
_claimation_ensure_running() {
    if ! proot-distro login debian -- pgrep -f "claimation-watchdog" >/dev/null 2>&1; then
        proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog >/dev/null 2>&1 &" &
        disown
    fi
}
_claimation_ensure_running
EOF

    # Termux:Boot
    mkdir -p ~/.termux/boot
    cat > ~/.termux/boot/claimation-start.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock; sleep 15
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog >/dev/null 2>&1 &"
EOF
    chmod +x ~/.termux/boot/claimation-start.sh
}

# ==============================================================================
# FINAL OUTPUT
# ==============================================================================
print_summary() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}✅ INSTALLATION COMPLETE!${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${YELLOW}🚨 REQUIRED: Restart Termux once to activate services${NC}"
    echo -e "   Swipe away Termux from recent apps and reopen it."
    echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}What happens after restart:${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Claimation will initialize itself (Termux/Android)    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Security Monitor active (Protects in PUBLIC mode)     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Auto-updater daemon runs as background service         ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Mode:${NC} ${MAGENTA}${MODE}${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Device:${NC} ${MAGENTA}${DEVICE}${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}\n"
}

# --- Main ---
clear
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│   TERMUX11 FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER     │${NC}"
echo -e "${CYAN}│                       v3.2                              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
check_env; setup_termux; setup_debian; configure_guest; setup_persistence; print_summary
