#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Termux11-Final-XFCE: One-Command Installer
# ==============================================================================
# Mirrors wsl-final-xfce architecture:
#   WSL  → systemd starts Xvfb + claimation automatically
#   Here → .bashrc hook starts termux-x11 + watchdog automatically
#
# Usage:
#   export CLAIM_USER="your_custom_user"
#   export CLAIM_PASS="your_custom_pass"
#   export CLAIM_FB="optional_firebase_id"
#   bash install.sh
# ==============================================================================
set -e

REPO_URL="https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-final-xfce"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
DEBIAN_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"

# Fetch latest Claimation version
echo "Fetching latest Claimation version..."
export CLAIMATION_VERSION=$(curl -fsSL https://raw.githubusercontent.com/rabbularafat/wsmation/main/latest-version.txt | head -n 1 | tr -d '\r')
if [ -z "$CLAIMATION_VERSION" ]; then
    echo "Warning: Failed to fetch latest version, falling back to 1.5.7"
    export CLAIMATION_VERSION="1.5.7"
fi
echo "Latest version: v${CLAIMATION_VERSION}"

# Claimation credentials from environment
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"

# --- Idempotent clean-up: strip old stale state and outdated .bashrc hooks ---
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
pkg install x11-repo -y
pkg install termux-x11-nightly proot-distro pulseaudio curl -y

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
DEBIAN_TMP_UTILS="$DEBIAN_ROOTFS/usr/local/bin/utils.sh"

# Ensure /usr/local/bin exists in rootfs
mkdir -p "$DEBIAN_ROOTFS/usr/local/bin"

if [ -f "$SCRIPTS_DIR/debian_setup.sh" ]; then
    cp "$SCRIPTS_DIR/debian_setup.sh" "$DEBIAN_TMP_SETUP"
    cp "$SCRIPTS_DIR/utils.sh" "$DEBIAN_TMP_UTILS"
else
    download_dependency "scripts/debian_setup.sh" "$DEBIAN_TMP_SETUP"
    download_dependency "scripts/utils.sh" "$DEBIAN_TMP_UTILS"
fi
chmod +x "$DEBIAN_TMP_SETUP"
chmod +x "$DEBIAN_TMP_UTILS"

# Initialize .env if it doesn't exist
if [ ! -f "$HOME/.env" ]; then
    echo "CLAIM_MODE=HEADLESS" > "$HOME/.env"
fi
# Copy .env to debian root (as /root/.env)
cp "$HOME/.env" "$DEBIAN_ROOTFS/root/.env"

# No --shared-tmp here — X11 not running during install (correct)
echo "--- Running internal Debian setup ---"
proot-distro login debian -- env \
    CLAIM_USER="$CLAIM_USER" \
    CLAIM_PASS="$CLAIM_PASS" \
    CLAIM_FB="$CLAIM_FB" \
    CLAIMATION_VERSION="$CLAIMATION_VERSION" \
    bash /tmp/setup_guest.sh
echo "--- Debian setup finished ---"

# ── Step 5: Termux-side auto-starter (.bashrc) ─────────────────────────────
# This is what makes Termux mirror WSL:
#   WSL  → systemd starts Xvfb + claimation at boot automatically
#   Here → .bashrc starts termux-x11 :0 + watchdog automatically on every session
#
# Result: opening ANY Termux session boots everything — no start-xfce needed
#         for claimation to run (start-xfce is only for the GUI desktop)

echo "[5/5] Writing auto-start hook to Termux ~/.bashrc..."

# Set fixed DISPLAY for Termux shell
if ! grep -q "export DISPLAY=:0" ~/.bashrc 2>/dev/null; then
    echo "export DISPLAY=:0" >> ~/.bashrc
fi

# Write the auto-starter (old hook was already stripped at top)
cat >> ~/.bashrc << 'TERMUX_BASHRC_EOF'

# claimation-autostart: mirrors WSL systemd — starts X11 + claimation automatically
_claimation_ensure_running() {
    # ── 0. Load display mode ─────────────────────────────────────────────
    _CLAIM_MODE="HEADLESS"
    if [ -f "$HOME/.env" ]; then
        _RAW_MODE=$(grep "^CLAIM_MODE=" "$HOME/.env" | cut -d'=' -f2 | sed 's/^["]//;s/["]$//;s/^['\'']//;s/['\'']$//')
        [ -n "$_RAW_MODE" ] && _CLAIM_MODE="$_RAW_MODE"
    fi

    # ── 1. Start termux-x11 :0 headlessly if in DEVELOPMENT mode ───────────
    if [ "$_CLAIM_MODE" = "DEVELOPMENT" ] || [ "$_CLAIM_MODE" = "dev" ]; then
        if ! pgrep -f "termux-x11" > /dev/null 2>&1; then
            echo "🖥️ Starting Termux:X11 display..."
            termux-x11 :0 > /dev/null 2>&1 &
            disown
            sleep 3
        fi
    fi

    # ── 3. Start the watchdog (maintains claimation 24/7) ───────
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
        # The watchdog inside Debian will now handle Xvfb vs Termux:X11 internal DISPLAY assignment
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
# Auto-start on phone reboot (requires Termux:Boot app)
termux-wake-lock
sleep 10

# Load display mode
_CLAIM_MODE="HEADLESS"
if [ -f "$HOME/.env" ]; then
    _RAW_MODE=$(grep "^CLAIM_MODE=" "$HOME/.env" | cut -d'=' -f2 | sed 's/^["]//;s/["]$//;s/^['\'']//;s/['\'']$//')
    [ -n "$_RAW_MODE" ] && _CLAIM_MODE="$_RAW_MODE"
fi

# Start X11 headlessly ONLY if in DEVELOPMENT mode
if [ "$_CLAIM_MODE" = "DEVELOPMENT" ] || [ "$_CLAIM_MODE" = "dev" ]; then
    termux-x11 :0 > /dev/null 2>&1 &
    sleep 2
fi

# Start watchdog (it will handle Xvfb vs Termux:X11 internally)
proot-distro login debian -- bash -c "nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &"
BOOT_EOF
chmod +x "$BOOT_DIR/claimation-start.sh"
echo "✅ Termux:Boot script: $BOOT_DIR/claimation-start.sh"

# ── start-xfce: optional GUI launcher (for the desktop, NOT needed for claimation) ──
START_SCRIPT="$PREFIX/bin/start-xfce"
cat > "$START_SCRIPT" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# start-xfce — Launch the XFCE desktop GUI
# NOTE: Claimation already runs headlessly from .bashrc.
#       This is only needed when you want the full XFCE visual desktop.

# If termux-x11 isn't running yet, start it
if ! pgrep -f "termux-x11" > /dev/null 2>&1; then
    termux-x11 :0 > /dev/null 2>&1 &
    sleep 2
fi

# Audio
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true

# Wake lock
termux-wake-lock

export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export XDG_RUNTIME_DIR=$TMPDIR

# Launch XFCE desktop inside Debian
proot-distro login debian -- bash -c "
# Load display mode to warn user
_CLAIM_MODE=\"HEADLESS\"
if [ -f \"/root/.env\" ]; then
    _RAW_MODE=\$(grep \"^CLAIM_MODE=\" \"/root/.env\" | cut -d'=' -f2 | sed 's/^[^\"]*[\"]//;s/[\"][^\"]*\$//;s/^[^\']*[\']//;s/[\'][^\']*\$//')
    [ -n \"\$_RAW_MODE\" ] && _CLAIM_MODE=\"\$_RAW_MODE\"
fi

if [ \"\$_CLAIM_MODE\" = \"HEADLESS\" ]; then
    echo \"⚠️  WARNING: System is in HEADLESS mode.\"
    echo \"   Watchdog will kill Termux:X11 display periodically.\"
    echo \"   To use GUI, set CLAIM_MODE=DEVELOPMENT in ~/.env and restart.\"
    echo \"\"
    sleep 2
fi

export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
startxfce4
"
EOF
chmod +x "$START_SCRIPT"
ln -sf "$START_SCRIPT" "$PREFIX/bin/termux11-final-xfce"
ln -sf "$START_SCRIPT" "$HOME/start-xfce.sh"
echo "✅ start-xfce launcher created (optional GUI only)"

# ── Apply .bashrc now ──────────────────────────────────────────────────────
source ~/.bashrc 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     ✨ INSTALLATION COMPLETE ✨          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "✅ Claimation runs 24/7 — just like WSL:"
echo "   Opening ANY Termux session auto-starts:"
echo "   ✓ termux-x11 :0 (headless X11 — like WSL's Xvfb)"
echo "   ✓ Claimation app + daemon"
echo ""
echo "🚀 NEXT STEPS:"
echo "   1. RESTART Termux (swipe away + reopen)"
echo "   2. Wait ~30s for claimation to start"
echo "   3. Verify: proot-distro login debian -- claimation status"
echo ""
echo "🖥️  OPTIONAL — Launch the full XFCE desktop:"
echo "   1. Open the Termux:X11 app"
echo "   2. Run: start-xfce"
echo ""
if [ -n "$CLAIM_USER" ]; then
    echo "✅ Claimation profile: $CLAIM_USER (auto-configured)"
fi
echo "📋 Phone-reboot persistence: pkg install termux-boot"
echo "══════════════════════════════════════════"
