#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# TERMUX FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER v4.0
# ==============================================================================
# Adapted from wsl-final-xfce/enterprise_installer.sh
# A professional, all-in-one script to transform Termux into a desktop OS
# with automated Claimation deployment running 24/7 in the background.
#
# Key difference from WSL: No systemd available in Termux proot.
# Solution: Host-side persistent watchdog that wraps proot-distro calls.
#
# Usage:
#   export CLAIM_USER="your_custom_user"
#   export CLAIM_PASS="your_custom_pass"
#   export CLAIM_FB="optional_firebase_id"
#   export MODE="DEVELOPMENT"  # DEVELOPMENT or PUBLIC
#   pkg update -y && pkg install curl -y && \
#   curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/termux-final-xfce/install.sh | bash
#
# After install: Close and reopen Termux (or just wait — it auto-activates).
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

# --- Logging Functions ---
log_step()    { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Debug Log Infrastructure ---
HOST_LOG_DIR="$HOME/.claimation"
HOST_DEBUG_LOG="$HOST_LOG_DIR/install-debug.log"
mkdir -p "$HOST_LOG_DIR" 2>/dev/null || true

log_debug() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${WHITE}[DEBUG]${NC} $1"
    echo "$msg" >> "$HOST_DEBUG_LOG"
}

# Redirect all output to both console AND log file
exec > >(tee -a "$HOST_DEBUG_LOG") 2>&1

# --- Deployment Configuration ---
MODE="${MODE:-PUBLIC}"
DEVICE="${DEVICE:-TERMUX}"

# ==============================================================================
# MODULE 0: Environment Validation & Architecture Check
# ==============================================================================
log_step "Environment Validation"

# Termux environment setup
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PREFIX/sbin:$PATH"

ARCH=$(uname -m)
log_info "Detected architecture: $ARCH"
log_debug "PREFIX=$PREFIX"
log_debug "PATH=$PATH"

case "$ARCH" in
    x86_64|aarch64|armv7l)
        log_success "Architecture $ARCH is supported."
        ;;
    *)
        log_error "╔══════════════════════════════════════════════════════════╗"
        log_error "║  UNSUPPORTED ARCHITECTURE: $ARCH"
        log_error "║  Claimation .deb requires: x86_64, aarch64, or armv7l"
        log_error "╚══════════════════════════════════════════════════════════╝"
        exit 1
        ;;
esac

# Verify we are running inside Termux
if [ ! -d "$PREFIX" ] || [ ! -x "$PREFIX/bin/pkg" ]; then
    log_error "This script must be run inside Termux."
    exit 1
fi
log_success "Termux environment confirmed."

# ==============================================================================
# MODULE 1: Auto-Detect Latest Version
# ==============================================================================
log_step "Detecting Latest Claimation Version"
CLAIMATION_VERSION=$(curl -fsSL https://raw.githubusercontent.com/rabbularafat/wsmation/main/latest-version.txt 2>/dev/null | tr -d '\r\n ' || echo "")

if [ -z "$CLAIMATION_VERSION" ]; then
    CLAIMATION_VERSION="1.7.1"
    log_warn "Could not fetch latest version. Falling back to v${CLAIMATION_VERSION}"
else
    log_success "Latest version detected: v${CLAIMATION_VERSION}"
fi

DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"
log_debug "DEB_URL=$DEB_URL"

# ==============================================================================
# MODULE 2: Host (Termux) Preparation
# ==============================================================================
log_step "Updating Termux Host Packages"

# Acquire wake lock to prevent Android from killing the process
termux-wake-lock 2>/dev/null || true

pkg update -y && pkg upgrade -y
pkg install x11-repo -y
pkg install termux-x11-nightly proot-distro pulseaudio curl wget openssl xxd -y

# Start host-side PulseAudio
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true

log_success "Host packages installed."

# ==============================================================================
# MODULE 3: Guest (Debian proot) Installation
# ==============================================================================
log_step "Installing Debian Guest (proot-distro)"

if ! proot-distro list | grep -q "debian.*installed"; then
    proot-distro install debian
    log_success "Debian installed."
else
    log_info "Debian already installed."
fi



# ==============================================================================
# MODULE 4: Guest Environment Setup (Single proot session)
# ==============================================================================
log_step "Configuring Debian Guest Environment"

DEBIAN_PATH="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"

# Write the guest setup script directly to the guest filesystem
cat > "$DEBIAN_PATH/tmp/setup_guest.sh" << 'GUEST_SCRIPT_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Colors for guest logging
BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; WHITE='\033[1;37m'; NC='\033[0m'
log_step()    { echo -e "\n${BLUE}[GUEST-STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[GUEST-OK]${NC} $1"; }
log_info()    { echo -e "${BLUE}[GUEST-INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[GUEST-WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[GUEST-ERROR]${NC} $1"; }

# Read arguments passed via environment file
source /tmp/guest_env.sh

# ---- 4a. System packages ----
log_step "Installing System Dependencies"
apt-get update
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get install -y sudo nano wget curl gnupg2 ca-certificates \
    dbus-x11 procps x11-xserver-utils xvfb xclip chromium coreutils openssl xxd

# ---- 4b. Download & Install Claimation .deb ----
log_step "Installing Claimation v${CLAIMATION_VERSION}"

wget -q --show-progress -O /tmp/claimation.deb "$DEB_URL"

# Verify download
if [ ! -s /tmp/claimation.deb ]; then
    log_error "FATAL: Failed to download claimation .deb package!"
    log_error "URL: $DEB_URL"
    exit 1
fi

# Mock systemctl (proot has no systemd)
if ! pidof systemd > /dev/null 2>&1; then
    log_info "No systemd detected (proot). Creating mock systemctl..."
    cat > /usr/bin/systemctl << 'MOCK_EOF'
#!/bin/bash
# Mock systemctl for proot environment
exit 0
MOCK_EOF
    chmod +x /usr/bin/systemctl
fi

dpkg -i /tmp/claimation.deb || apt-get install -f -y
rm -f /tmp/claimation.deb

# ---- 4c. Verification & Diagnostics ----
log_step "Running Post-Install Diagnostics"

DEBUG_LOG="/root/.claimation/logs/install-debug.log"
mkdir -p /root/.claimation/logs

{
    echo "============================================"
    echo "POST-INSTALL DIAGNOSTICS: $(date)"
    echo "============================================"
    echo "Architecture: $(uname -m)"

    # Binary check
    CLAIMATION_BIN=$(which claimation 2>/dev/null || echo "NOT_FOUND")
    echo "Binary Path: $CLAIMATION_BIN"

    if [ "$CLAIMATION_BIN" != "NOT_FOUND" ] && [ -x "$CLAIMATION_BIN" ]; then
        echo "Binary is EXECUTABLE: YES"

        # Version check
        echo "Version Output:"
        claimation --version 2>&1 || echo "  (--version failed)"

        # Library dependency check
        echo ""
        echo "Library Dependencies (ldd):"
        if command -v ldd >/dev/null 2>&1; then
            ldd "$CLAIMATION_BIN" 2>&1 || echo "  (ldd failed — may be a script)"
            MISSING=$(ldd "$CLAIMATION_BIN" 2>&1 | grep "not found" || true)
            if [ -n "$MISSING" ]; then
                echo "!!! MISSING LIBRARIES DETECTED !!!"
                echo "$MISSING"
            else
                echo "  All libraries OK."
            fi
        else
            echo "  ldd not available (this is OK for Python packages)"
        fi

        # Quick dry-run test
        echo ""
        echo "Quick execution test (claimation --help):"
        timeout 10 claimation --help 2>&1 | head -5 || echo "  (help command failed/timed out)"
    else
        echo "!!! FATAL: claimation binary NOT FOUND or NOT EXECUTABLE !!!"
        echo "PATH=$PATH"
        echo "Contents of /usr/local/bin/:"
        ls -la /usr/local/bin/ 2>/dev/null || echo "  (dir missing)"
        echo "Contents of /usr/bin/claimation*:"
        ls -la /usr/bin/claimation* 2>/dev/null || echo "  (no matches)"
    fi
    echo "============================================"
} 2>&1 | tee -a "$DEBUG_LOG"

# FATAL check
if ! which claimation >/dev/null 2>&1; then
    log_error "╔══════════════════════════════════════════════════════════╗"
    log_error "║  FATAL: claimation binary not found after installation! ║"
    log_error "║  Check debug log: $DEBUG_LOG                           ║"
    log_error "╚══════════════════════════════════════════════════════════╝"
    exit 1
fi
log_success "Binary verified: $(which claimation)"

# ---- 4d. Apply Configuration (from installed package) ----
log_step "Applying Profile Configuration"
CONFIGURE_SCRIPT="/usr/lib/claimation/scripts/configure-profile.sh"
if [ -f "$CONFIGURE_SCRIPT" ]; then
    bash "$CONFIGURE_SCRIPT"
    log_success "Configuration applied successfully."
else
    log_warn "Configuration script not found. Manual setup required."
fi

log_success "Guest setup complete."
GUEST_SCRIPT_EOF

chmod +x "$DEBIAN_PATH/tmp/setup_guest.sh"

# Write environment variables to a separate file the guest script sources
cat > "$DEBIAN_PATH/tmp/guest_env.sh" << ENV_EOF
export CLAIMATION_VERSION="$CLAIMATION_VERSION"
export DEB_URL="$DEB_URL"
export CLAIM_USER="$CLAIM_USER"
export CLAIM_FB="$CLAIM_FB"
export CLAIM_PASS="$CLAIM_PASS"
export MODE="$MODE"
export DEVICE="$DEVICE"
ENV_EOF

# Execute the guest setup
log_step "Executing Guest Setup Inside proot-distro..."
proot-distro login debian -- bash /tmp/setup_guest.sh

# Clean up env file (contains credentials)
rm -f "$DEBIAN_PATH/tmp/guest_env.sh"

# ==============================================================================
# MODULE 5: Enterprise GUI Setup (if app includes it)
# ==============================================================================
GUI_SCRIPT="/usr/lib/claimation/installation/termux_gui.sh"
if proot-distro login debian -- test -f "$GUI_SCRIPT"; then
    log_step "Executing Enterprise GUI Setup (Mode: $MODE) — Wait 3-5 mins..."
    proot-distro login debian -- bash -c "export MODE='$MODE'; export DEVICE='$DEVICE'; bash $GUI_SCRIPT"
else
    log_info "No GUI setup script found in package. Skipping."
fi

# ==============================================================================
# MODULE 6: HOST-SIDE Persistent Watchdog (THE CRITICAL FIX)
# ==============================================================================
# WHY THIS IS DIFFERENT FROM WSL:
#   WSL uses systemd services that persist across sessions.
#   Termux has NO systemd. Processes inside proot die when the session exits.
#
# SOLUTION: The watchdog runs on the HOST (Termux) side as a background script.
#   It uses `proot-distro login debian -- ...` to check and start claimation
#   inside the guest. The HOST process persists as long as Termux is alive +
#   wake-lock is active.
# ==============================================================================
log_step "Creating Host-Side Persistent Watchdog"

WATCHDOG_SCRIPT="$HOME/.claimation/claimation-watchdog.sh"
cat > "$WATCHDOG_SCRIPT" << 'WATCHDOG_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# CLAIMATION HOST-SIDE WATCHDOG FOR TERMUX v4.0
# ==============================================================================
# This runs on the Termux HOST, NOT inside proot.
# It manages Xvfb + claimation inside the Debian guest via proot-distro calls.
#
# ARCHITECTURE (why this works):
#   - Processes launched via `nohup cmd &` inside a proot session DIE when
#     the proot session exits. There is no systemd to keep them alive.
#   - SOLUTION: We open a LONG-LIVED proot session that runs claimation in
#     the FOREGROUND. The proot session stays alive as long as claimation runs.
#   - When claimation crashes, the proot session exits, and THIS watchdog
#     (running on the HOST) detects it and restarts everything.
# ==============================================================================

export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$PREFIX/sbin:$PATH"

LOG_DIR="$HOME/.claimation/logs"
WATCHDOG_LOG="$LOG_DIR/watchdog.log"
mkdir -p "$LOG_DIR"

# Redirect watchdog output to log
exec >> "$WATCHDOG_LOG" 2>&1

echo ""
echo "================================================================"
echo " WATCHDOG STARTED: $(date)"
echo " PID: $$"
echo " Host Arch: $(uname -m)"
echo "================================================================"

# Ensure wake-lock is active
termux-wake-lock 2>/dev/null || true

# Helper: run a short command inside the Debian guest
guest_exec() {
    proot-distro login debian --shared-tmp -- bash -c "$1" 2>&1
}

# Startup delay — give proot time to settle after install
sleep 5

FAIL_COUNT=0
MAX_FAILS=5
CLAIMATION_PROOT_PID=""
XVFB_PROOT_PID=""

# --- Cleanup on exit ---
cleanup() {
    echo "[$(date)] Watchdog shutting down..."
    [ -n "$CLAIMATION_PROOT_PID" ] && kill "$CLAIMATION_PROOT_PID" 2>/dev/null
    [ -n "$XVFB_PROOT_PID" ] && kill "$XVFB_PROOT_PID" 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

# ==============================================================================
# MAIN WATCHDOG LOOP
# ==============================================================================
while true; do
    echo "[$(date)] --- Health check ---"

    # ------------------------------------------------------------------
    # 1. Ensure Xvfb is running inside guest (via a long-lived session)
    # ------------------------------------------------------------------
    if [ -n "$XVFB_PROOT_PID" ] && kill -0 "$XVFB_PROOT_PID" 2>/dev/null; then
        echo "[$(date)] Xvfb session alive (host PID: $XVFB_PROOT_PID)"
    else
        echo "[$(date)] Starting Xvfb :99 inside guest..."
        # Launch Xvfb in foreground inside a long-lived proot session
        proot-distro login debian --shared-tmp -- bash -c "
            export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            # Kill any stale Xvfb
            pkill -f 'Xvfb :99' 2>/dev/null || true
            sleep 1
            # Run Xvfb in FOREGROUND — keeps proot session alive
            exec Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset
        " >> "$LOG_DIR/xvfb.log" 2>&1 &
        XVFB_PROOT_PID=$!
        echo "[$(date)] Xvfb proot session launched (host PID: $XVFB_PROOT_PID)"
        sleep 3

        # Verify
        if kill -0 "$XVFB_PROOT_PID" 2>/dev/null; then
            echo "[$(date)] Xvfb confirmed running."
        else
            echo "[$(date)] WARNING: Xvfb proot session died immediately!"
            echo "  --- xvfb.log tail ---"
            tail -10 "$LOG_DIR/xvfb.log" 2>/dev/null
            echo "  ---------------------"
        fi
    fi

    # ------------------------------------------------------------------
    # 2. Ensure claimation is running inside guest (via a long-lived session)
    # ------------------------------------------------------------------
    if [ -n "$CLAIMATION_PROOT_PID" ] && kill -0 "$CLAIMATION_PROOT_PID" 2>/dev/null; then
        echo "[$(date)] Claimation session alive (host PID: $CLAIMATION_PROOT_PID)"
        FAIL_COUNT=0
    else
        if [ -n "$CLAIMATION_PROOT_PID" ]; then
            echo "[$(date)] Claimation proot session EXITED (was PID: $CLAIMATION_PROOT_PID)"
        fi
        echo "[$(date)] Starting claimation inside guest..."

        # Launch claimation in FOREGROUND inside a long-lived proot session.
        # The proot session stays alive as long as claimation runs.
        # When claimation crashes/exits, the proot session exits, and we detect it
        # on the NEXT health check and restart.
        proot-distro login debian --shared-tmp -- bash -c "
            export DISPLAY=:99
            export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            mkdir -p /root/.claimation/logs

            echo '[GUEST] === Claimation session starting: \$(date) ===' >> /root/.claimation/logs/claimation.log

            # Pre-flight checks
            CLAIM_BIN=\$(which claimation 2>/dev/null)
            if [ -z \"\$CLAIM_BIN\" ]; then
                echo '[GUEST] FATAL: claimation binary not found!' >> /root/.claimation/logs/claimation.log
                echo '[GUEST] PATH='\$PATH >> /root/.claimation/logs/claimation.log
                ls -la /usr/local/bin/ /usr/bin/claim* 2>&1 >> /root/.claimation/logs/claimation.log
                exit 1
            fi

            echo '[GUEST] Binary: '\$CLAIM_BIN >> /root/.claimation/logs/claimation.log
            echo '[GUEST] Display: '\$DISPLAY >> /root/.claimation/logs/claimation.log
            echo '[GUEST] Xvfb check: '\$(pgrep -f 'Xvfb :99' || echo 'NOT RUNNING') >> /root/.claimation/logs/claimation.log

            # Run claimation in FOREGROUND — this keeps the proot session alive
            exec claimation run --skip-update-check >> /root/.claimation/logs/claimation.log 2>&1
        " &
        CLAIMATION_PROOT_PID=$!
        echo "[$(date)] Claimation proot session launched (host PID: $CLAIMATION_PROOT_PID)"

        # Wait and verify the session is still alive
        sleep 8
        if kill -0 "$CLAIMATION_PROOT_PID" 2>/dev/null; then
            echo "[$(date)] SUCCESS: Claimation session confirmed alive after 8s."
            FAIL_COUNT=0
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo "[$(date)] FAIL #${FAIL_COUNT}: Claimation proot session died within 8s."

            # Dump debug info
            echo "[$(date)] --- Debug Info ---"
            echo "  Last 20 lines of claimation.log:"
            guest_exec "tail -20 /root/.claimation/logs/claimation.log 2>/dev/null || echo '(no log)'"
            echo ""
            echo "  Binary check:"
            guest_exec "which claimation 2>/dev/null && claimation --version 2>&1 || echo 'binary not found'"
            echo ""
            echo "  Library check:"
            guest_exec "ldd \$(which claimation 2>/dev/null) 2>&1 | grep -i 'not found' || echo 'All deps OK (or not an ELF)'"
            echo "[$(date)] --- End Debug ---"

            if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
                echo "[$(date)] ╔════════════════════════════════════════════╗"
                echo "[$(date)] ║  CRITICAL: ${MAX_FAILS} consecutive failures!       ║"
                echo "[$(date)] ╚════════════════════════════════════════════╝"
                echo ""
                echo "[$(date)] === FULL DEBUG DUMP ==="
                guest_exec "
                    echo '--- System Info ---'
                    echo 'Arch: '\$(uname -m)
                    echo 'Python: '\$(which python3 2>/dev/null || echo NOT_FOUND)
                    echo 'Python version: '\$(python3 --version 2>&1 || echo unknown)
                    echo ''
                    echo '--- Package Info ---'
                    dpkg -l | grep -i claim 2>/dev/null || echo '(claimation not in dpkg)'
                    echo ''
                    echo '--- Install Directory ---'
                    ls -la /usr/lib/claimation/ 2>/dev/null || echo '(dir missing)'
                    echo ''
                    echo '--- Last 50 lines claimation.log ---'
                    tail -50 /root/.claimation/logs/claimation.log 2>/dev/null || echo '(no log)'
                "
                echo "[$(date)] === END FULL DEBUG DUMP ==="
                echo "[$(date)] Cooling down 5 minutes before retry..."
                sleep 300
                FAIL_COUNT=0
            fi
        fi
    fi

    # Health check interval
    sleep 60
done
WATCHDOG_EOF
chmod +x "$WATCHDOG_SCRIPT"
log_success "Watchdog script created at $WATCHDOG_SCRIPT"

# ==============================================================================
# MODULE 7: Start-XFCE Desktop Script (DEVELOPMENT mode only)
# ==============================================================================
if [ "$MODE" = "DEVELOPMENT" ]; then
    log_step "Creating Desktop Launch Script (DEVELOPMENT mode)"

    cat > "$HOME/start-xfce.sh" << 'XFCE_EOF'
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
XFCE_EOF
    chmod +x "$HOME/start-xfce.sh"
    log_success "Desktop script: ~/start-xfce.sh"
else
    log_info "PUBLIC mode — skipping desktop script (headless operation)."
fi

# ==============================================================================
# MODULE 8: Bashrc Persistence & Aliases
# ==============================================================================
log_step "Configuring Shell Persistence"
touch ~/.bashrc

# Aliases
if [ "$MODE" = "DEVELOPMENT" ]; then
    grep -q "alias start-xfce" ~/.bashrc 2>/dev/null || \
        echo "alias start-xfce='bash ~/start-xfce.sh'" >> ~/.bashrc
fi

grep -q "alias claimation-logs" ~/.bashrc 2>/dev/null || \
    echo "alias claimation-logs='proot-distro login debian -- tail -f /root/.claimation/logs/claimation.log'" >> ~/.bashrc

grep -q "alias claimation-status" ~/.bashrc 2>/dev/null || \
    echo "alias claimation-status='proot-distro login debian -- claimation status'" >> ~/.bashrc

grep -q "alias claimation-debug" ~/.bashrc 2>/dev/null || \
    echo "alias claimation-debug='cat ~/.claimation/logs/watchdog.log'" >> ~/.bashrc

# Auto-start persistence hook
# This is the KEY to 24/7 operation: every time a Termux session opens,
# it checks if the watchdog is running and starts it if not.
grep -q "claimation-autostart-v4" ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'BASHRC_EOF'

# claimation-autostart-v4
_claimation_ensure_running() {
    # Check if our HOST-SIDE watchdog is already running
    if ! pgrep -f "claimation-watchdog.sh" >/dev/null 2>&1; then
        echo -e "\033[0;36m[Claimation]\033[0m Starting 24/7 watchdog..."
        termux-wake-lock 2>/dev/null || true
        nohup bash "$HOME/.claimation/claimation-watchdog.sh" </dev/null &>/dev/null &
        disown
        sleep 2
        if pgrep -f "claimation-watchdog.sh" >/dev/null 2>&1; then
            echo -e "\033[0;32m[Claimation]\033[0m Watchdog active ✓"
        else
            echo -e "\033[0;31m[Claimation]\033[0m Watchdog failed to start! Check: cat ~/.claimation/logs/watchdog.log"
        fi
    fi
}
_claimation_ensure_running
BASHRC_EOF

log_success "Persistence configured in .bashrc"

# ==============================================================================
# MODULE 9: Immediate Activation (Don't Wait for Shell Restart)
# ==============================================================================
log_step "Activating Watchdog NOW (Instant Start)"

# Kill any old watchdogs first
pkill -f "claimation-watchdog" 2>/dev/null || true
sleep 1

# Start the host-side watchdog
nohup bash "$WATCHDOG_SCRIPT" </dev/null &>/dev/null &
disown
WATCHDOG_PID=$!
sleep 5

# Verify watchdog is running
if pgrep -f "claimation-watchdog.sh" >/dev/null 2>&1; then
    log_success "Watchdog is RUNNING (PID: $(pgrep -f 'claimation-watchdog.sh'))"
else
    log_error "Watchdog failed to start! Debug log:"
    cat "$HOME/.claimation/logs/watchdog.log" 2>/dev/null | tail -20
fi

# Wait for claimation to actually start
log_info "Waiting for claimation to start inside guest (up to 30s)..."
STARTED=false
for i in $(seq 1 6); do
    sleep 5
    if proot-distro login debian -- pgrep -f "claimation run" >/dev/null 2>&1; then
        STARTED=true
        break
    fi
    echo -n "."
done
echo ""

if [ "$STARTED" = true ]; then
    log_success "claimation is RUNNING inside guest! 🎉"
else
    log_warn "claimation hasn't started yet. The watchdog will keep retrying."
    log_warn "Check logs: cat ~/.claimation/logs/watchdog.log"
fi

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✅ INSTALLATION COMPLETE! (Termux Enterprise v4.0)${NC}   ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}What's happening now:${NC}                                  ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Host-side watchdog running (survives session exit)    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Xvfb virtual display active at :99                   ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Claimation starting/running in background             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Auto-restart on crash (60s health checks)             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Auto-start on Termux reopen                           ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Mode:${NC} ${MAGENTA}${MODE}${NC}                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Device:${NC} ${MAGENTA}${DEVICE}${NC}                                      ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"



echo ""
echo -e "${YELLOW}📋 Useful Commands:${NC}"
echo -e "   ${WHITE}claimation-status${NC}  — Check if bot is running"
echo -e "   ${WHITE}claimation-logs${NC}    — Stream bot output"
echo -e "   ${WHITE}claimation-debug${NC}   — View watchdog log"
if [ "$MODE" = "DEVELOPMENT" ]; then
    echo -e "   ${WHITE}start-xfce${NC}         — Launch desktop (DEVELOPMENT mode)"
fi
echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Debug Logs:${NC}                                            ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    Install:  ${MAGENTA}~/.claimation/install-debug.log${NC}            ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    Watchdog: ${MAGENTA}~/.claimation/logs/watchdog.log${NC}            ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    Bot:      ${MAGENTA}(inside guest) /root/.claimation/logs/${NC}     ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
echo ""
