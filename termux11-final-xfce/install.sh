#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX11 FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER v3.11 (Total Zero-Touch)
# ==============================================================================
# A professional, all-in-one script to transform Termux into a desktop OS
# with automated Claimation deployment running 24/7 in the background.
# ==============================================================================

set -e

# --- Configuration & Styling ---
BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Debug Logging Infrastructure ---
DEBUG_LOG="/root/.claimation/logs/install-debug.log"
HOST_DEBUG_LOG="$HOME/.claimation-install.log"
mkdir -p "$HOME/.claimation" 2>/dev/null || true

log_debug() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${WHITE}[DEBUG]${NC} $1"
    echo "$msg" >> "$HOST_DEBUG_LOG"
}

# --- 1. Environment & Architecture Detection ---
log_step "Environment Validation"

# Architecture compatibility check
ARCH=$(uname -m)
log_info "Detected architecture: $ARCH"
case "$ARCH" in
    x86_64|aarch64|armv7l) 
        log_success "Architecture $ARCH is supported."
        ;;
    *) 
        log_error "Unsupported architecture: $ARCH"
        exit 1 
        ;;
esac

log_step "Detecting Latest Version"
VERSION=$(curl -fsSL https://raw.githubusercontent.com/rabbularafat/wsmation/main/latest-version.txt | tr -d '\r\n ' || echo "1.7.1")
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

# Start host-side PulseAudio
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true

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
apt install -y sudo nano wget curl gnupg2 ca-certificates dbus-x11 procps x11-xserver-utils xvfb xclip chromium

wget -q -O /tmp/claimation.deb "${DEB_URL}"
# Mock systemctl for .deb installer
if ! pidof systemd > /dev/null 2>&1; then
    echo -e "#!/bin/bash\nexit 0" > /usr/bin/systemctl && chmod +x /usr/bin/systemctl
fi
dpkg -i /tmp/claimation.deb || apt install -f -y
rm -f /tmp/claimation.deb

# --- Runtime Diagnostics ---
log_step "Running Diagnostics"
mkdir -p /root/.claimation/logs
{
    echo "--- Installation Diagnostics ($(date)) ---"
    echo "Architecture: $(uname -m)"
    echo "Binary Path: $(which claimation || echo 'NOT FOUND')"
    if [ -x "$(which claimation)" ]; then
        echo "Binary Version: $(claimation --version 2>&1 || echo 'Error running --version')"
        echo "Library Dependencies:"
        ldd "$(which claimation)" 2>&1 || echo "ldd failed"
    fi
    echo "------------------------------------------"
} | tee -a /root/.claimation/logs/install-debug.log

if ! which claimation >/dev/null 2>&1; then
    echo -e "\n\${RED}[FATAL] Claimation binary not found after installation!\${NC}"
    exit 1
fi

log_step "Injecting Zero-Touch Credentials"
mkdir -p /etc/claimation
echo -e "MODE=\"$MODE\"\nDEVICE=\"$DEVICE\"\nCLAIM_USER=\"$CLAIM_USER\"" > /etc/claimation/config.env

# Smart Credential Injection
if [ -n "$CLAIM_USER" ]; then
    PROFILE_DIR="/root/.config/chromium-browser/ZxcvbnPkData/$CLAIM_USER"
    mkdir -p "\$PROFILE_DIR"
    [ -n "$CLAIM_FB" ] && echo "$CLAIM_FB" > "\$PROFILE_DIR/firebase_id.txt"
    
    if [ -n "$CLAIM_PASS" ]; then
        if [[ "\$CLAIM_PASS" == *==* ]]; then
            echo -n "\$CLAIM_PASS" > "\$PROFILE_DIR/claim_pass.txt"
        else
            key=\$(echo -n "DistroClaimationSecretKey2024!24/7" | openssl dgst -sha256 -binary | xxd -p -c 32)
            echo -n "\$CLAIM_PASS" | openssl enc -aes-256-cbc -K "\$key" -iv "00000000000000000000000000000000" -base64 -A > "\$PROFILE_DIR/claim_pass.txt"
        fi
    fi
    mkdir -p "/root/.claimation"
    echo "Setup by distro installer v3.11" > "/root/.claimation/.setup_done"
fi

log_step "Creating Watchdog Service"
cat <<'WATCHDOG_EOF' > /usr/local/bin/claimation-watchdog
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PREFIX="/data/data/com.termux/files/usr"
LOG="/root/.claimation/logs/watchdog.log"
mkdir -p /root/.claimation/logs

# Redirect all watchdog output to log
exec >> "$LOG" 2>&1
echo "=== Watchdog started: $(date) ==="

# Ensure Xvfb virtual display is running at :99
if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
    echo "[$(date)] Starting Xvfb :99..."
    Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 3
fi
export DISPLAY=:99

while true; do
    # Verify and restart core process
    if ! pgrep -f "claimation run" >/dev/null 2>&1; then
        echo "[$(date)] claimation not running. Starting..."
        # We use a separate log for the actual bot output
        claimation run --skip-update-check >> /root/.claimation/logs/claimation.log 2>&1 &
        CPID=$!
        sleep 5
        if ! kill -0 $CPID 2>/dev/null; then
            echo "[$(date)] ERROR: claimation exited immediately. Debug info follows:"
            echo "  Path: $(which claimation)"
            echo "  Display: $DISPLAY"
            echo "  Xvfb: $(pgrep -f 'Xvfb :99' || echo 'NOT RUNNING')"
            echo "--- Last 20 lines of bot log ---"
            tail -n 20 /root/.claimation/logs/claimation.log
            echo "--------------------------------"
            sleep 120 # Cool down to prevent loop spam
        else
            echo "[$(date)] claimation started successfully (PID: $CPID)"
        fi
    fi
    sleep 60
done
WATCHDOG_EOF
chmod +x /usr/local/bin/claimation-watchdog
GUEST_EOF

chmod +x "$DEBIAN_TMP_SETUP"
proot-distro login debian -- bash /tmp/setup_guest.sh

# --- 4. Synchronous GUI Setup ---
log_step "Executing Enterprise GUI Setup (Mode: $MODE) - Wait 3-5 mins..."
proot-distro login debian -- bash -c "export MODE='$MODE'; export DEVICE='$DEVICE'; bash /usr/lib/claimation/installation/termux_gui.sh"

# --- 5. Host Persistence & Logging ---
log_step "Configuring Host Persistence & Logs"
touch ~/.bashrc

# Start-XFCE Script
cat <<'EOF' > "$HOME/start-xfce.sh"
#!/data/data/com.termux/files/usr/bin/bash
pkill -f termux-x11 2>/dev/null; pkill -f Xwayland 2>/dev/null
termux-x11 :0 >/dev/null 2>&1 &

# PulseAudio Fix
if ! pgrep pulseaudio > /dev/null; then
    pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
    pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true
fi

termux-wake-lock; sleep 2
export DISPLAY=:0; export PULSE_SERVER=127.0.0.1; export XDG_RUNTIME_DIR=$TMPDIR
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; env DISPLAY=:0 startxfce4"
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
        # Use setsid to ensure the process detaches from the current session properly
        proot-distro login debian --shared-tmp -- bash -c "mkdir -p /root/.claimation/logs; nohup setsid /usr/local/bin/claimation-watchdog </dev/null &>/root/.claimation/logs/watchdog.log & disown; sleep 1" &
        disown
    fi
}
_claimation_ensure_running
EOF

# --- 6. Final Activation ---
log_step "Starting Services (Instant Activation)"
proot-distro login debian --shared-tmp -- bash -c "
    mkdir -p /root/.claimation/logs
    echo '[$(date)] Manual activation triggered' >> /root/.claimation/logs/watchdog.log
    nohup setsid /usr/local/bin/claimation-watchdog </dev/null &>/root/.claimation/logs/watchdog.log & 
    disown
    sleep 3
    if pgrep -f claimation-watchdog >/dev/null; then
        echo 'Watchdog started successfully'
    else
        echo 'FATAL: Watchdog failed to start at activation'
        [ -f /root/.claimation/logs/watchdog.log ] && tail -n 20 /root/.claimation/logs/watchdog.log
    fi
" &
disown

# --- Summary ---
echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✅ TOTAL ZERO-TOUCH INSTALL COMPLETE! (v3.11)${NC}        ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "\n${YELLOW}🚨 24/7 OPERATION ACTIVE: The bot is starting...${NC}"
echo -e "   - Check Status: ${WHITE}claimation-status${NC}"
echo -e "   - Monitor Logs: ${WHITE}claimation-logs${NC}"
echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Configured User:${NC} ${MAGENTA}${CLAIM_USER}${NC}                             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Active Mode:${NC}     ${MAGENTA}${MODE}${NC}                                   ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}\n"
