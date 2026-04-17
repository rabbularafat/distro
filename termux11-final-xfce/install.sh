#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Termux11-Final-XFCE: One-Command Installer (Modern X11 version)
# ==============================================================================
# Installs Debian XFCE + Claimation in Termux via proot-distro + Termux:X11
#
# Usage:
#   export CLAIM_USER="your_custom_user"
#   export CLAIM_PASS="your_custom_pass"
#   export CLAIM_FB="optional_firebase_id"
#   bash install.sh
# ==============================================================================
set -e

# Repository URL for downloading dependencies
REPO_URL="https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-final-xfce"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

# Claimation credentials from environment
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"

# Helper Function: Download dependencies if they don't exist locally
download_dependency() {
    local file=$1
    local dest=$2
    if [ ! -f "$dest" ]; then
        echo "Downloading dependency: $file..."
        mkdir -p "$(dirname "$dest")"
        curl -fsSL "$REPO_URL/$file" -o "$dest" || {
            echo "Error: Failed to download $file. Check your internet connection."
            exit 1
        }
    fi
}

echo "╔══════════════════════════════════════════╗"
echo "║  Termux11-Final-XFCE + Claimation Installer   ║"
echo "╚══════════════════════════════════════════╝"

# 1. Update Termux and Install Core Packages
echo "[1/5] Updating Termux packages..."
pkg update -y && pkg upgrade -y
pkg install x11-repo -y
pkg install termux-x11-nightly proot-distro pulseaudio curl -y

# 2. Install Debian (XFCE base) via proot-distro
if ! proot-distro list | grep -q "debian.*installed"; then
    echo "[2/5] Installing Debian (this may take a moment)..."
    proot-distro install debian
else
    echo "[2/5] Debian is already installed."
fi

# 3. Setup Script inside Debian
echo "[3/5] Configuring the Debian desktop environment + Claimation..."
DEBIAN_PATH="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
DEBIAN_TMP_SETUP="$DEBIAN_PATH/tmp/setup_guest.sh"

# If scripts dir exists (cloned repo case), use local script, otherwise download.
if [ -f "$SCRIPTS_DIR/debian_setup.sh" ]; then
    cp "$SCRIPTS_DIR/debian_setup.sh" "$DEBIAN_TMP_SETUP"
else
    download_dependency "scripts/debian_setup.sh" "$DEBIAN_TMP_SETUP"
fi

chmod +x "$DEBIAN_TMP_SETUP"

# Run the guest setup inside proot, passing credentials as environment variables
echo "--- Running internal setup (installing XFCE, Claimation, fonts) ---"
proot-distro login debian -- env \
    CLAIM_USER="$CLAIM_USER" \
    CLAIM_PASS="$CLAIM_PASS" \
    CLAIM_FB="$CLAIM_FB" \
    bash /tmp/setup_guest.sh
echo "--- Internal setup finished ---"

# 4. Create the Start/Launch Script
echo "[4/5] Creating the 'start-xfce' launcher..."
START_SCRIPT="$HOME/start-xfce.sh"

cat <<'EOF' > "$START_SCRIPT"
#!/data/data/com.termux/files/usr/bin/bash

# Cleanup old sessions
pkill -f termux-x11 2>/dev/null
pkill -f Xwayland 2>/dev/null

# Start Termux:X11 display server
termux-x11 :0 >/dev/null 2>&1 &

# Audio setup
pulseaudio --start --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

# Acquire Wake Lock (Prevent Android from sleeping Termux)
termux-wake-lock

# Give server time to initialize
sleep 2

# Export display and environment
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export XDG_RUNTIME_DIR=$TMPDIR

# Start Debian Desktop via proot
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; export PULSE_SERVER=127.0.0.1; startxfce4"
EOF

chmod +x "$START_SCRIPT"

# Create alias for easy launch
if ! grep -q "alias start-xfce" ~/.bashrc 2>/dev/null; then
    echo "alias start-xfce='bash $START_SCRIPT'" >> ~/.bashrc
fi

# 5. Set fixed DISPLAY=:0 for Termux shell (Termux:X11 always uses :0)
if ! grep -q "export DISPLAY=:0" ~/.bashrc 2>/dev/null; then
    echo "export DISPLAY=:0" >> ~/.bashrc
fi

# 6. Auto-start Claimation watchdog when opening ANY Termux session
# (Belt-and-suspenders: even without start-xfce, claimation stays alive)
if ! grep -q "claimation-autostart" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'TERMUX_BASHRC_EOF'

# claimation-autostart: Auto-launch watchdog inside proot on every Termux session
# The watchdog itself prevents duplicate instances, so this is safe to call repeatedly.
_claimation_ensure_running() {
    # Check if the watchdog is already running inside proot
    if ! proot-distro login debian -- pgrep -f "claimation-watchdog" > /dev/null 2>&1; then
        echo "🔄 Starting Claimation watchdog..."
        proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &" &
        disown
    fi
}
_claimation_ensure_running
TERMUX_BASHRC_EOF
    echo "Termux auto-start hook added to Termux .bashrc"
fi

# 7. Setup Termux:Boot for phone-reboot persistence
# If Termux:Boot is installed, create a boot script that auto-starts
# the proot watchdog when the phone reboots.
BOOT_DIR="$HOME/.termux/boot"
mkdir -p "$BOOT_DIR"

cat > "$BOOT_DIR/claimation-start.sh" << 'BOOT_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Claimation Termux:Boot Auto-Start
# Runs on phone boot if Termux:Boot app is installed.

# Acquire wake lock to prevent Android from killing Termux
termux-wake-lock

# Wait a moment for system to stabilize
sleep 10

# Start the watchdog inside Debian proot (headless, no desktop needed)
proot-distro login debian --shared-tmp -- bash -c "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &"
BOOT_EOF

chmod +x "$BOOT_DIR/claimation-start.sh"
echo "Termux:Boot script created at $BOOT_DIR/claimation-start.sh"

source ~/.bashrc 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     ✨ INSTALLATION COMPLETE ✨          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "🚀 NEXT STEPS (CRITICAL):"
echo "1. RESTART Termux: Swipe away the Termux app from recent apps and reopen it."
echo "2. WAIT 30s: Give the background watchdog a moment to start Claimation."
echo "3. VERIFY: Type 'proot-distro login debian -- claimation status' to see 🟢 RUNNING."
echo ""
echo "📱 GUI SETUP:"
echo "1. Install 'Termux:X11' Android APK if you haven't already."
echo "2. Open 'Termux:X11' app to the black screen."
echo "3. In Termux, type: start-xfce"
echo ""
echo "🔒 24/7 PERSISTENCE:"
echo "  ✓ Auto-starts on every Termux session"
echo "  ✓ Auto-starts on phone boot (Termux:Boot)"
echo "  ✓ Auto-restarts if claimation crashes"
echo ""
if [ -n "$CLAIM_USER" ]; then
    echo "✅ Claimation Profile: $CLAIM_USER (auto-configured)"
else
    echo "⚠️  No CLAIM_USER set. Run 'claimation run' inside Debian for setup."
fi
echo ""
echo "📋 INSTALL Termux:Boot for phone-reboot persistence:"
echo "   pkg install termux-boot"
echo "   (Then open Termux:Boot app once to enable it)"
echo ""
echo "Note: Termux:X11 always uses DISPLAY=:0 (fixed)."
echo "      GUI apps (chromium, etc.) work directly — no manual setup needed."
echo "══════════════════════════════════════════"
