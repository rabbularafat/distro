#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Termux11-Final-XFCE: One-Command Installer
# ==============================================================================
# Mirrors wsl-final-xfce architecture:
#   WSL  → systemd starts Xvfb + overlay + claimation automatically
#   Here → .bashrc hook starts termux-x11 + watchdog automatically
#
# Usage:
#   export CLAIM_USER="your_custom_user"
#   export CLAIM_PASS="your_custom_pass"
#   export CLAIM_FB="optional_firebase_id"
#   bash install.sh
# ==============================================================================
set -e

REPO_URL="https://raw.githubusercontent.com/rabbularafat/distro/main/termuxVnc-final-xfce"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
DEBIAN_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"

# Claimation credentials from environment
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"

# --- Idempotent clean-up ---
rm -f "$DEBIAN_ROOTFS/tmp/claimation-watchdog.pid"    2>/dev/null || true

# Remove ALL old auto-start blocks so re-install always writes the latest version
if grep -q "claimation-autostart" "$HOME/.bashrc" 2>/dev/null; then
    python3 - "$HOME/.bashrc" <<'STRIP_EOF'
import sys, re
fname = sys.argv[1]
with open(fname, 'r') as f: content = f.read()
content = re.sub(
    r'\n# claimation-autostart:.*?\n_claimation_ensure_running\n',
    '\n', content, flags=re.DOTALL
)
with open(fname, 'w') as f: f.write(content)
print("Old .bashrc claimation-autostart hook removed.")
STRIP_EOF
fi

# Helper: download file if not present locally
download_dependency() {
    local file=$1 dest=$2
    if [ ! -f "$dest" ]; then
        echo "Downloading: $file..."
        mkdir -p "$(dirname "$dest")"
        curl -fsSL "$REPO_URL/$file" -o "$dest" || { echo "ERROR: failed to download $file"; exit 1; }
    fi
}

echo "╔══════════════════════════════════════════╗"
echo "║  Termux11-Final-XFCE + Claimation        ║"
echo "╚══════════════════════════════════════════╝"

# ── Step 1: Termux packages ────────────────────────────────────────────────
echo "[1/5] Updating Termux packages..."
pkg update -y && pkg upgrade -y
pkg install proot-distro pulseaudio curl -y

# ── Step 2: Install Debian via proot-distro ────────────────────────────────
if ! proot-distro list | grep -q "debian.*installed"; then
    echo "[2/5] Installing Debian (this may take a moment)..."
    proot-distro install debian
else
    echo "[2/5] Debian already installed."
fi

# ── Step 3: Run debian_setup.sh inside Debian ──────────────────────────────
echo "[3/5] Configuring Debian desktop + Claimation..."
DEBIAN_TMP_SETUP="$DEBIAN_ROOTFS/tmp/setup_guest.sh"

if [ -f "$SCRIPTS_DIR/debian_setup.sh" ]; then
    cp "$SCRIPTS_DIR/debian_setup.sh" "$DEBIAN_TMP_SETUP"
else
    download_dependency "scripts/debian_setup.sh" "$DEBIAN_TMP_SETUP"
fi
chmod +x "$DEBIAN_TMP_SETUP"

# No --shared-tmp here — X11 not running during install (correct)
echo "--- Running internal Debian setup ---"
proot-distro login debian -- env \
    CLAIM_USER="$CLAIM_USER" \
    CLAIM_PASS="$CLAIM_PASS" \
    CLAIM_FB="$CLAIM_FB" \
    bash /tmp/setup_guest.sh
echo "--- Debian setup finished ---"

# ── Step 4: Termux-side auto-starter (.bashrc) ─────────────────────────────
echo "[4/4] Writing auto-start hook to Termux ~/.bashrc..."

# Write the auto-starter
cat >> ~/.bashrc << 'TERMUX_BASHRC_EOF'

# claimation-autostart: starts VNC server + watchdog on login
_claimation_ensure_running() {
    _WD_PID_FILE="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/tmp/claimation-watchdog.pid"
    _WD_RUNNING=false
    if [ -f "$_WD_PID_FILE" ]; then
        _OLD_PID=$(cat "$_WD_PID_FILE" 2>/dev/null)
        if [ -n "$_OLD_PID" ] && kill -0 "$_OLD_PID" 2>/dev/null; then
            _WD_RUNNING=true
        fi
    fi

    if [ "$_WD_RUNNING" = false ]; then
        echo "🔄 Starting Claimation Background Services (VNC + Watchdog)..."
        proot-distro login debian -- bash -c "nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &" &
        disown
    fi
}
_claimation_ensure_running
TERMUX_BASHRC_EOF

echo "✅ Auto-start hook written to ~/.bashrc"

# ── Termux:Boot — persist after phone reboot ──────────────────────────────
BOOT_DIR="$HOME/.termux/boot"
mkdir -p "$BOOT_DIR"
cat > "$BOOT_DIR/claimation-start.sh" << 'BOOT_EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
sleep 10
proot-distro login debian -- bash -c "nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &"
BOOT_EOF
chmod +x "$BOOT_DIR/claimation-start.sh"
echo "✅ Termux:Boot script: $BOOT_DIR/claimation-start.sh"

# ── Apply .bashrc now ──────────────────────────────────────────────────────
source ~/.bashrc 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     ✨ INSTALLATION COMPLETE ✨          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "✅ Claimation is now running invisibly in the background."
echo "   No Termux:X11 app needed. No visual interference."
echo ""
echo "🚀 NEXT STEPS:"
echo "   1. RESTART Termux (swipe away + reopen)"
echo "   2. Wait ~30s for claimation to start"
echo "   3. Verify: proot-distro login debian -- claimation status"
echo ""
echo "🖥️  ADMIN GUI ACCESS (VNC):"
echo "   If you want to watch the screen, connect using a VNC Viewer:"
echo "   1. Open Android VNC Viewer app (e.g. RealVNC)"
echo "   2. Connect to: localhost:5901"
echo "   3. Password: \$CLAIM_PASS (Your claimation password)"
echo ""
if [ -n "$CLAIM_USER" ]; then
    echo "✅ Claimation profile: $CLAIM_USER (auto-configured)"
fi
echo "📋 Phone-reboot persistence: pkg install termux-boot"
echo "══════════════════════════════════════════"
