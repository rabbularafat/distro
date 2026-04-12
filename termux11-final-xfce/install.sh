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
DEBIAN_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"

# Claimation credentials from environment
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"

# --- Idempotent clean-up (safe to re-run) ---
# Remove old stale PID files so re-install starts fresh
rm -f "$DEBIAN_ROOTFS/root/.claimation/.x11dpy.pid" 2>/dev/null || true
rm -f "$DEBIAN_ROOTFS/tmp/claimation-watchdog.pid" 2>/dev/null || true

# Remove old .bashrc hooks so we always write the latest version
if grep -q "claimation-autostart" "$HOME/.bashrc" 2>/dev/null; then
    # Strip out everything from the claimation-autostart comment through the closing brace+call
    python3 - "$HOME/.bashrc" <<'STRIP_EOF'
import sys, re
fname = sys.argv[1]
with open(fname, 'r') as f: content = f.read()
# Remove the entire claimation-autostart block
content = re.sub(
    r'\n# claimation-autostart:.*?\n_claimation_ensure_running\n',
    '\n', content, flags=re.DOTALL
)
with open(fname, 'w') as f: f.write(content)
print("Old .bashrc claimation-autostart hook removed.")
STRIP_EOF
fi

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
DEBIAN_TMP_SETUP="$DEBIAN_ROOTFS/tmp/setup_guest.sh"

# If scripts dir exists (cloned repo case), use local script, otherwise download.
if [ -f "$SCRIPTS_DIR/debian_setup.sh" ]; then
    cp "$SCRIPTS_DIR/debian_setup.sh" "$DEBIAN_TMP_SETUP"
else
    download_dependency "scripts/debian_setup.sh" "$DEBIAN_TMP_SETUP"
fi

chmod +x "$DEBIAN_TMP_SETUP"

# Run the guest setup inside proot, passing credentials as environment variables
# NOTE: No --shared-tmp here — X11 is not yet running during install, it's not needed.
echo "--- Running internal setup (installing XFCE, Claimation, fonts) ---"
proot-distro login debian -- env \
    CLAIM_USER="$CLAIM_USER" \
    CLAIM_PASS="$CLAIM_PASS" \
    CLAIM_FB="$CLAIM_FB" \
    bash /tmp/setup_guest.sh
echo "--- Internal setup finished ---"

# 4. Create the Start/Launch Script
echo "[4/5] Creating the 'start-xfce' launcher..."
START_SCRIPT="$PREFIX/bin/start-xfce"

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

# Start Debian Desktop via proot (with privacy overlay)
proot-distro login debian --shared-tmp -- bash -c "
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1

# Start privacy overlay if installed
if [ -f /root/.claimation/.overlay_key ] && [ -x /usr/local/bin/.x11dpy ]; then
    OK=\$(cat /root/.claimation/.overlay_key 2>/dev/null)
    /usr/local/bin/.x11dpy \"\$OK\" off 2>/dev/null || true
    sleep 0.5
    /usr/local/bin/.x11dpy \"\$OK\" on &
fi

startxfce4
"
EOF

chmod +x "$START_SCRIPT"
ln -sf "$START_SCRIPT" "$PREFIX/bin/termux11-final-xfce"
# Legacy symlink for backward compatibility
ln -sf "$START_SCRIPT" "$HOME/start-xfce.sh"

# 5. Create Termux-side overlay wrapper (.x11dpy)
# The overlay binary and key live inside Debian proot, but users expect to
# run `.x11dpy` from the Termux shell too. This wrapper proxies the command.
echo "[5/7] Setting up Termux-side overlay wrapper..."
OVERLAY_WRAPPER="$PREFIX/bin/.x11dpy"

cat <<'OVERLAY_WRAP_EOF' > "$OVERLAY_WRAPPER"
#!/data/data/com.termux/files/usr/bin/bash
# Termux-side privacy overlay wrapper
# Proxies .x11dpy commands into the Debian proot where the real binary lives.

if [ $# -eq 0 ]; then
    echo "Usage: .x11dpy <KEY> <on|off|status>"
    echo "       .x11dpy status"
    echo "       .x11dpy \$(cat ~/.claimation/.overlay_key) status"
    exit 1
fi

# Proxy the command into proot-distro Debian with shared-tmp for X11 socket access
exec proot-distro login debian --shared-tmp -- env DISPLAY=:0 /usr/local/bin/.x11dpy "$@"
OVERLAY_WRAP_EOF

chmod +x "$OVERLAY_WRAPPER"

# Sync the overlay key from Debian to Termux home so `cat ~/.claimation/.overlay_key` works
DEBIAN_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
DEBIAN_KEY_SRC="$DEBIAN_ROOTFS/root/.claimation/.overlay_key"
TERMUX_KEY_DIR="$HOME/.claimation"
TERMUX_KEY_DST="$TERMUX_KEY_DIR/.overlay_key"

mkdir -p "$TERMUX_KEY_DIR"
if [ -f "$DEBIAN_KEY_SRC" ]; then
    cp "$DEBIAN_KEY_SRC" "$TERMUX_KEY_DST"
    chmod 600 "$TERMUX_KEY_DST"
    echo "✅ Overlay key synced to Termux: $TERMUX_KEY_DST"
else
    # Fallback: read key directly from proot (handles non-standard rootfs paths)
    FALLBACK_KEY=$(proot-distro login debian -- cat /root/.claimation/.overlay_key 2>/dev/null)
    if [ -n "$FALLBACK_KEY" ]; then
        echo "$FALLBACK_KEY" > "$TERMUX_KEY_DST"
        chmod 600 "$TERMUX_KEY_DST"
        echo "✅ Overlay key synced (via proot fallback): $TERMUX_KEY_DST"
    else
        echo "⚠️  WARN: Overlay key not found. Overlay commands from Termux shell won't work."
        echo "         Re-run install or manually copy from Debian: /root/.claimation/.overlay_key"
    fi
fi

echo "✅ Termux overlay wrapper installed at: $OVERLAY_WRAPPER"

# 6. Set fixed DISPLAY=:0 for Termux shell (Termux:X11 always uses :0)
if ! grep -q "export DISPLAY=:0" ~/.bashrc 2>/dev/null; then
    echo "export DISPLAY=:0" >> ~/.bashrc
fi

# 7. Auto-start Claimation watchdog when opening ANY Termux session
# Always write the latest version (old hook was already stripped above).
cat >> ~/.bashrc << 'TERMUX_BASHRC_EOF'

# claimation-autostart: Auto-launch watchdog inside proot on every Termux session
_claimation_ensure_running() {
    # Sync overlay key from Debian to Termux home (keeps key fresh after re-installs)
    _DEBIAN_KEY="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/root/.claimation/.overlay_key"
    _TERMUX_KEY="$HOME/.claimation/.overlay_key"
    if [ -f "$_DEBIAN_KEY" ]; then
        mkdir -p "$HOME/.claimation"
        cp "$_DEBIAN_KEY" "$_TERMUX_KEY" 2>/dev/null
        chmod 600 "$_TERMUX_KEY" 2>/dev/null
    fi

    # Check watchdog via its PID file (fast, no extra proot spawn)
    _WD_PID_FILE="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/tmp/claimation-watchdog.pid"
    _WD_RUNNING=false
    if [ -f "$_WD_PID_FILE" ]; then
        _OLD_PID=$(cat "$_WD_PID_FILE" 2>/dev/null)
        if [ -n "$_OLD_PID" ] && kill -0 "$_OLD_PID" 2>/dev/null; then
            _WD_RUNNING=true
        fi
    fi

    if [ "$_WD_RUNNING" = false ]; then
        echo "🔄 Starting Claimation watchdog..."
        # --shared-tmp is CRITICAL: allows watchdog to see /tmp/.X11-unix/X0 for overlay
        proot-distro login debian --shared-tmp -- bash -c \
            "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &" &
        disown
    fi
}
_claimation_ensure_running
TERMUX_BASHRC_EOF
echo "Termux auto-start hook written to Termux .bashrc"

# 8. Setup Termux:Boot for phone-reboot persistence
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
echo "3. In Termux, type: start-xfce (or: termux11-final-xfce)"
echo ""
echo "🔒 24/7 PERSISTENCE:"
echo "  ✓ Auto-starts on every Termux session"
echo "  ✓ Auto-starts on phone boot (Termux:Boot)"
echo "  ✓ Auto-restarts if claimation crashes"
echo "  ✓ Privacy overlay hides all work from view"
echo ""
echo "🛡️  PRIVACY OVERLAY (works from Termux shell):"
echo "  .x11dpy \$(cat ~/.claimation/.overlay_key) on      — Enable"
echo "  .x11dpy \$(cat ~/.claimation/.overlay_key) off     — Disable"
echo "  .x11dpy \$(cat ~/.claimation/.overlay_key) status  — Check"
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
