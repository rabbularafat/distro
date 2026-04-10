#!/bin/bash

# Debian Guest Setup Script (Termux11-XFCE)
# Runs INSIDE proot-distro Debian for Termux:X11
set -e

echo "--- [GUEST] Starting Debian internal configuration ---"

# 1. Update Debian
echo "[1/5] Updating Debian repositories..."
apt update && apt upgrade -y

# 2. Install Desktop Components
echo "[2/5] Installing XFCE4, Terminal, Chromium, and GUI tools..."
apt install sudo nano wget curl xfce4 xfce4-goodies dbus-x11 -y
apt install chromium fonts-noto-core fonts-noto-color-emoji -y
# xclip: required by pyperclip for clipboard operations
apt install xclip x11-xserver-utils -y

# 3. Chromium Sandboxing Fix (proot doesn't support kernel sandboxing)
echo "[3/5] Configuring Chromium flags for proot support..."
mkdir -p /etc/chromium.d
echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox"' > /etc/chromium.d/proot-flags

# Set Chromium as default browser
update-alternatives --set x-www-browser /usr/bin/chromium 2>/dev/null || true
update-alternatives --set gnome-www-browser /usr/bin/chromium 2>/dev/null || true

# 4. User and Environment Configuration
echo "[4/5] Finalizing environment settings..."

# Fix DBUS issues for XFCE
mkdir -p /run/dbus
dbus-uuidgen > /etc/machine-id || true

# Inject fixed DISPLAY=:0 into .bashrc (Termux:X11 always uses :0)
if ! grep -q "export DISPLAY=:0" /root/.bashrc 2>/dev/null; then
    echo "" >> /root/.bashrc
    echo "# Termux:X11 fixed display" >> /root/.bashrc
    echo "export DISPLAY=:0" >> /root/.bashrc
fi

echo "--- [GUEST] Environment configuration complete ---"

# --- [CLAIMATION] Automated Installation & Setup ---
echo "[5/5] Starting Claimation automation..."

# 5a. Install Claimation .deb
CLAIMATION_VERSION="1.5.3"
DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"

wget -q --show-progress -O /tmp/claimation.deb "$DEB_URL"
dpkg -i /tmp/claimation.deb || true
apt install -f -y
rm -f /tmp/claimation.deb

# 5aa. Apply Hotfix to installed app.py (Solve Permission/Status issues)
# ---------------------------------------------------------------
echo "Applying automated hotfixes to installed Claimation code..."
APP_PY="/usr/lib/claimation/claimation/app.py"

if [ -f "$APP_PY" ]; then
    # Fix Status Path Logic (check for write access instead of just existence)
    sed -i 's/if os.geteuid() == 0 or os.path.exists(STATUS_DIR):/if os.path.exists(STATUS_DIR) and os.access(STATUS_DIR, os.W_OK):/' "$APP_PY"
    
    # Fix startup sync fallback (remove the fallback to read-only source path)
    sed -i 's/initial_ext_path = get_extension_source_path()/initial_ext_path = None/' "$APP_PY"
    
    echo "Hotfixes applied successfully."
else
    echo "WARN: Could not find app.py at $APP_PY. Skipping hotfix."
fi

# 5b. Pre-configure profile to bypass interactive setup
# CLAIM_USER, CLAIM_FB are passed from the parent Termux environment
FOLDER_NAME="${CLAIM_USER:-}"
FIREBASE_ID="${CLAIM_FB:-}"
ZXCVBN_DIR="/root/.config/chromium-browser/ZxcvbnPkData"

if [ -n "$FOLDER_NAME" ]; then
    echo "Pre-configuring Claimation profile for '${FOLDER_NAME}'..."
    mkdir -p "$ZXCVBN_DIR/$FOLDER_NAME"

    # Store Firebase ID if provided
    if [ -n "$FIREBASE_ID" ]; then
        echo "$FIREBASE_ID" > "$ZXCVBN_DIR/$FOLDER_NAME/firebase_id.txt"
    fi
else
    echo "WARN: CLAIM_USER not set. Claimation will require manual setup on first run."
fi

# 5c. Setup XFCE autostart for Claimation (starts with desktop session)
mkdir -p /root/.config/autostart
cat > /root/.config/autostart/claimation.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Claimation
Exec=claimation run
Icon=utilities-terminal
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo "--- [GUEST] Claimation automation complete ---"
