#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX11 FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER v3.8 (Dynamic & Robust)
# ==============================================================================
# A professional, all-in-one script to transform Termux into a desktop OS
# with automated Claimation deployment running 24/7 in the background.
# ==============================================================================

set -e

# --- Configuration & Styling ---
BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

log_step()    { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 1. Dynamic Version Discovery ---
log_step "Detecting Latest Version"
# Automatically pull the latest version from your repository
VERSION=$(curl -fsSL https://raw.githubusercontent.com/rabbularafat/claimation/main/latest-version.txt | tr -d '\r\n ' || echo "1.7.1")
DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${VERSION}/claimation_${VERSION}-1_all.deb"
log_info "Targeting Claimation v${VERSION}"

# --- Config ---
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"
MODE="${MODE:-PUBLIC}"
DEVICE="${DEVICE:-TERMUX}"

# --- 2. Host Preparation ---
log_step "Updating Termux Base"
termux-wake-lock || true
pkg update -y && pkg upgrade -y
pkg install x11-repo -y
pkg install termux-x11-nightly proot-distro pulseaudio curl wget openssl xxd -y

# --- 3. Guest Installation ---
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

log_step "Installing Base Application (v$VERSION)"
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

log_step "Creating Watchdog Service"
cat <<'WATCHDOG_EOF' > /usr/local/bin/claimation-watchdog
#!/bin/bash
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

# --- 4. Synchronous GUI Setup (CRITICAL FIX) ---
# We must pass the environment variables so XFCE actually installs
log_step "Executing Enterprise GUI Setup (Mode: $MODE) - Wait 3-5 mins..."
proot-distro login debian -- bash -c "export MODE='$MODE'; export DEVICE='$DEVICE'; bash /usr/lib/claimation/installation/termux_gui.sh"

# --- 5. Host Persistence & Logging ---
log_step "Configuring Host Persistence & Logs"
touch ~/.bashrc

# Start-XFCE Script (Hardened PulseAudio)
cat <<'EOF' > "$HOME/start-xfce.sh"
#!/data/data/com.termux/files/usr/bin/bash
# 1. Cleanup old sessions
pkill -f termux-x11 2>/dev/null; pkill -f Xwayland 2>/dev/null

# 2. Start Termux:X11
termux-x11 :0 >/dev/null 2>&1 &

# 3. Robust PulseAudio Start
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true

# 4. Wait for display
termux-wake-lock; sleep 2
export DISPLAY=:0; export PULSE_SERVER=127.0.0.1; export XDG_RUNTIME_DIR=$TMPDIR

# 5. Launch XFCE
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; startxfce4"
EOF
chmod +x "$HOME/start-xfce.sh"

# Bashrc aliases
grep -q "alias start-xfce" ~/.bashrc || echo "alias start-xfce='bash ~/start-xfce.sh'" >> ~/.bashrc
grep -q "alias claimation-logs" ~/.bashrc || echo "alias claimation-logs='proot-distro login debian -- tail -f /root/.claimation/logs/claimation.log'" >> ~/.bashrc
grep -q "alias claimation-status" ~/.bashrc || echo "alias claimation-status='proot-distro login debian -- claimation status'" >> ~/.bashrc

# Persistence Hook
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

# --- 6. Final Activation ---
log_step "Starting Services (Instant Activation)"
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog >/dev/null 2>&1 &"

# --- Summary ---
echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✅ INSTALLATION COMPLETE! (v3.8)${NC}                      ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "\n${YELLOW}🚨 READY: Version ${VERSION} is active.${NC}"
echo -e "   - Check Status: ${WHITE}claimation-status${NC}"
echo -e "   - Launch Desktop: ${WHITE}start-xfce${NC}"
echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Mode:${NC} ${MAGENTA}${MODE}${NC}                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Device:${NC} ${MAGENTA}${DEVICE}${NC}                                      ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}\n"
