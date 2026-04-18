#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX11 FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER v3.5 (Robust Release)
# ==============================================================================
# A professional, all-in-one script to transform Termux into a desktop OS
# with automated Claimation deployment running 24/7 in the background.
# ==============================================================================

set -e

# --- Configuration & Styling ---
BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

# Version Track
VERSION="1.7.0"
DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${VERSION}/claimation_${VERSION}-1_all.deb"

log_step()    { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Config ---
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"
MODE="${MODE:-PUBLIC}"
DEVICE="${DEVICE:-TERMUX}"

# --- Setup Host ---
log_step "Updating Termux Base"
termux-wake-lock || true
pkg update -y && pkg upgrade -y
pkg install x11-repo -y
pkg install termux-x11-nightly proot-distro pulseaudio curl wget openssl xxd -y

# --- Setup Guest ---
log_step "Installing Debian (proot-distro)"
if ! proot-distro list | grep -q "debian.*installed"; then
    proot-distro install debian
fi

log_step "Configuring Internal Debian Environment"
DEBIAN_PATH="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
DEBIAN_TMP_SETUP="$DEBIAN_PATH/tmp/setup_guest.sh"

cat << GUEST_EOF > "$DEBIAN_TMP_SETUP"
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
log_step() { echo -e "\${CYAN}[GUEST-STEP]\${NC} \$1"; }

log_step "Installing Base Application"
apt update && apt upgrade -y
apt install -y sudo nano wget curl gnupg2 ca-certificates dbus-x11 x11-xserver-utils xvfb xclip chromium

wget -q -O /tmp/claimation.deb "${DEB_URL}"
if ! pidof systemd > /dev/null 2>&1; then
    echo -e "#!/bin/bash\nexit 0" > /usr/bin/systemctl && chmod +x /usr/bin/systemctl
fi
dpkg -i /tmp/claimation.deb || apt install -f -y
rm -f /tmp/claimation.deb

log_step "Persisting Configuration"
mkdir -p /etc/claimation
echo -e "MODE=\"$MODE\"\nDEVICE=\"$DEVICE\"\nCLAIM_USER=\"$CLAIM_USER\"" > /etc/claimation/config.env

# Apply Hotfixes
APP_PY="/usr/lib/claimation/claimation/app.py"
if [ -f "\$APP_PY" ]; then
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
GUEST_EOF

chmod +x "$DEBIAN_TMP_SETUP"
proot-distro login debian -- bash /tmp/setup_guest.sh

# --- Setup Persistence ---
log_step "Configuring Host Persistence"
# Ensure .bashrc exists
touch ~/.bashrc

# Start-XFCE Script
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

# Bashrc hooks
grep -q "alias start-xfce" ~/.bashrc || echo "alias start-xfce='bash ~/start-xfce.sh'" >> ~/.bashrc
grep -q "claimation-autostart" ~/.bashrc || cat >> ~/.bashrc << 'EOF'
# claimation-autostart
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

# --- Immediate Activation ---
log_step "Starting Services (Instant Activation)"
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog >/dev/null 2>&1 &"

# --- Summary ---
echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✅ INSTALLATION COMPLETE! (v3.5)${NC}                      ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "\n${YELLOW}🚨 READY: Services are already running in background${NC}"
echo -e "   You can check status now: proot-distro login debian -- claimation status"
echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Mode:${NC} ${MAGENTA}${MODE}${NC}                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Device:${NC} ${MAGENTA}${DEVICE}${NC}                                      ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}\n"
