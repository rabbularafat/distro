#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Termux11-Final-XFCE: Overlay Repair Script
# Run this from Termux to fix overlay issues on existing installations.
# Usage:  bash repair-overlay.sh
# ==============================================================================

set -e

REPO_URL="https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-final-xfce"
DEBIAN_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
TERMUX_KEY_DIR="$HOME/.claimation"
TERMUX_KEY_DST="$TERMUX_KEY_DIR/.overlay_key"
DEBIAN_KEY_SRC="$DEBIAN_ROOTFS/root/.claimation/.overlay_key"

echo "╔══════════════════════════════════════════╗"
echo "║  Overlay Repair — Termux11-Final-XFCE   ║"
echo "╚══════════════════════════════════════════╝"

# Step 1: Kill any stale overlay daemon inside Debian
echo "[1/6] Clearing stale overlay state..."
proot-distro login debian -- bash -c "
    PID_FILE=/root/.claimation/.x11dpy.pid
    if [ -f \"\$PID_FILE\" ]; then
        OLD_PID=\$(cat \"\$PID_FILE\" 2>/dev/null)
        if [ -n \"\$OLD_PID\" ]; then
            kill -9 \"\$OLD_PID\" 2>/dev/null || true
        fi
        rm -f \"\$PID_FILE\"
        echo '  Stale PID file cleared.'
    else
        echo '  No stale PID file found.'
    fi
" || true

# Step 2: Re-install the fixed overlay.py into Debian proot
echo "[2/6] Installing fixed overlay binary into Debian proot..."
DEBIAN_SETUP_URL="$REPO_URL/scripts/debian_setup.sh"

# Extract and re-install just the overlay binary
# We generate a minimal re-install script that patches .x11dpy in place
proot-distro login debian -- bash <<'PATCH_EOF'
# Download and patch the .x11dpy binary from GitHub
echo "  Downloading latest overlay.py..."
OVERLAY_PY_URL="https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-final-xfce/scripts/debian_setup.sh"

# Extract overlay.py content from debian_setup.sh (between OVERLAY_PY_EOF markers)
curl -fsSL "$OVERLAY_PY_URL" -o /tmp/debian_setup_latest.sh || {
    echo "  ERROR: Failed to download debian_setup.sh"
    exit 1
}

# Pull out just the Python content of .x11dpy
sed -n "/^cat > \/usr\/local\/bin\/.x11dpy/,/^OVERLAY_PY_EOF/p" /tmp/debian_setup_latest.sh \
    | grep -v "^cat " | grep -v "^OVERLAY_PY_EOF" > /tmp/new_x11dpy.py

if [ -s /tmp/new_x11dpy.py ]; then
    cp /tmp/new_x11dpy.py /usr/local/bin/.x11dpy
    chmod +x /usr/local/bin/.x11dpy
    echo "  overlay.py updated."
else
    echo "  WARN: Could not extract overlay.py. Keeping existing binary."
fi
rm -f /tmp/debian_setup_latest.sh /tmp/new_x11dpy.py
PATCH_EOF

# Step 3: Ensure .overlay_key exists inside Debian (regenerate if missing)
echo "[3/6] Ensuring overlay key is set..."
KEY_EXISTS=$(proot-distro login debian -- test -f /root/.claimation/.overlay_key && echo "yes" || echo "no")
if [ "$KEY_EXISTS" = "no" ]; then
    echo "  Key missing inside Debian — regenerating..."
    NEW_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    proot-distro login debian -- bash -c "
        mkdir -p /root/.claimation
        echo '$NEW_KEY' > /root/.claimation/.overlay_key
        chmod 600 /root/.claimation/.overlay_key
        /usr/local/bin/.x11dpy --init '$NEW_KEY'
        echo '  Auth key initialized.'
    "
else
    echo "  Key exists inside Debian — re-initializing auth hash..."
    EXISTING_KEY=$(proot-distro login debian -- cat /root/.claimation/.overlay_key 2>/dev/null)
    proot-distro login debian -- /usr/local/bin/.x11dpy --init "$EXISTING_KEY" 2>/dev/null || true
fi

# Step 4: Sync key to Termux home
echo "[4/6] Syncing overlay key to Termux home..."
mkdir -p "$TERMUX_KEY_DIR"
if [ -f "$DEBIAN_KEY_SRC" ]; then
    cp "$DEBIAN_KEY_SRC" "$TERMUX_KEY_DST"
    chmod 600 "$TERMUX_KEY_DST"
    echo "  Key synced: $TERMUX_KEY_DST"
else
    FALLBACK_KEY=$(proot-distro login debian -- cat /root/.claimation/.overlay_key 2>/dev/null)
    if [ -n "$FALLBACK_KEY" ]; then
        echo "$FALLBACK_KEY" > "$TERMUX_KEY_DST"
        chmod 600 "$TERMUX_KEY_DST"
        echo "  Key synced (via proot): $TERMUX_KEY_DST"
    else
        echo "  ERROR: Could not read key from Debian proot."
        exit 1
    fi
fi

# Step 5: Re-install the Termux-side .x11dpy wrapper
echo "[5/6] Re-installing Termux-side wrapper..."
OVERLAY_WRAPPER="$PREFIX/bin/.x11dpy"
cat > "$OVERLAY_WRAPPER" << 'WRAPPER_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Termux-side privacy overlay wrapper — proxies into Debian proot
if [ $# -eq 0 ]; then
    echo "Usage: .x11dpy <KEY> <on|off|status>"
    echo "       .x11dpy \$(cat ~/.claimation/.overlay_key) status"
    exit 1
fi
exec proot-distro login debian --shared-tmp -- env DISPLAY=:0 /usr/local/bin/.x11dpy "$@"
WRAPPER_EOF
chmod +x "$OVERLAY_WRAPPER"
echo "  Wrapper installed: $OVERLAY_WRAPPER"

# Step 6: Fix Termux .bashrc if the old pgrep-based hook is present
echo "[6/6] Patching Termux .bashrc watchdog hook..."
if grep -q "proot-distro login debian -- pgrep" ~/.bashrc 2>/dev/null; then
    # Remove the old broken hook
    sed -i '/# claimation-autostart:/,/_claimation_ensure_running$/d' ~/.bashrc 2>/dev/null || true
    # Remove the old function definition and call
    python3 - ~/.bashrc <<'PYEOF'
import sys, re
fname = sys.argv[1]
with open(fname, 'r') as f: content = f.read()
# Remove old claimation-autostart block
pattern = r'\n# claimation-autostart:.*?_claimation_ensure_running\n'
content = re.sub(pattern, '\n', content, flags=re.DOTALL)
with open(fname, 'w') as f: f.write(content)
print("  Old bashrc hook removed.")
PYEOF
fi

# Add the fixed hook if not already present
if ! grep -q "claimation-autostart" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'TERMUX_BASHRC_EOF'

# claimation-autostart: Auto-launch watchdog inside proot on every Termux session
_claimation_ensure_running() {
    # Sync overlay key from Debian to Termux home (if missing)
    _DEBIAN_KEY="$PREFIX/var/lib/proot-distro/installed-rootfs/debian/root/.claimation/.overlay_key"
    _TERMUX_KEY="$HOME/.claimation/.overlay_key"
    if [ -f "$_DEBIAN_KEY" ] && [ ! -f "$_TERMUX_KEY" ]; then
        mkdir -p "$HOME/.claimation"
        cp "$_DEBIAN_KEY" "$_TERMUX_KEY"
        chmod 600 "$_TERMUX_KEY"
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
        # --shared-tmp is CRITICAL: allows watchdog to see /tmp/.X11-unix/X0
        proot-distro login debian --shared-tmp -- bash -c \
            "export DISPLAY=:0; nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &" &
        disown
    fi
}
_claimation_ensure_running
TERMUX_BASHRC_EOF
    echo "  Fixed .bashrc hook installed."
else
    echo "  .bashrc hook already present."
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     ✅ REPAIR COMPLETE                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""
KEY=$(cat "$TERMUX_KEY_DST" 2>/dev/null)
echo "🔑 Your overlay key: $KEY"
echo ""
echo "📋 TEST NOW (while XFCE desktop is running):"
echo "   1. Open Termux:X11 and run: start-xfce"
echo "   2. In a NEW Termux tab, run:"
echo "      .x11dpy \$(cat ~/.claimation/.overlay_key) status   # Should return: 1"
echo "      .x11dpy \$(cat ~/.claimation/.overlay_key) off      # Disable"
echo "      .x11dpy \$(cat ~/.claimation/.overlay_key) on       # Enable"
echo ""
echo "   Or from inside proot:"
echo "      proot-distro login debian -- claimation status"
echo ""
echo "🔄 Restart Termux to activate the fixed .bashrc hook."
