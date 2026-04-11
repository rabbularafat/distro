#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Termux11-XFCE: One-Command Installer (Modern X11 version)
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
REPO_URL="https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-xfce"
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
echo "║  Termux11-XFCE + Claimation Installer   ║"
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

source ~/.bashrc 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     ✨ INSTALLATION COMPLETE ✨          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "🚀 NEXT STEPS:"
echo "1. Install the 'Termux:X11' Android APK if you haven't already."
echo "2. Open the 'Termux:X11' app to the black/waiting screen."
echo "3. Go back to Termux and type: start-xfce"
echo ""
if [ -n "$CLAIM_USER" ]; then
    echo "✅ Claimation Profile: $CLAIM_USER (auto-configured)"
    echo "   Claimation will auto-start when the desktop launches."
else
    echo "⚠️  No CLAIM_USER set. Run 'claimation run' inside Debian for first-time setup."
fi
echo ""
echo "Note: Termux:X11 always uses DISPLAY=:0 (fixed)."
echo "      GUI apps (chromium, etc.) work directly — no manual setup needed."
echo "══════════════════════════════════════════"
