#!/bin/bash

# Debian Guest Setup Script (Termux11-XFCE)
# Runs INSIDE proot-distro Debian for Termux:X11
set -e

echo "--- [GUEST] Starting Debian internal configuration ---"

# Automate installations (No prompts)
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Pre-configure keyboard and timezone to prevent interactive prompts
# These are mapped to English (US) by default as requested.
echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | debconf-set-selections 2>/dev/null || true
echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | debconf-set-selections 2>/dev/null || true
echo 'keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)' | debconf-set-selections 2>/dev/null || true
echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | debconf-set-selections 2>/dev/null || true
echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections 2>/dev/null || true
echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections 2>/dev/null || true

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

# 5a. Install Claimation .deb (with systemd bypass for proot)
CLAIMATION_VERSION="1.5.3"
DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"

wget -q --show-progress -O /tmp/claimation.deb "$DEB_URL"

# In proot (Termux), systemd is unavailable. The claimation .deb post-install
# script tries to run systemctl, which fails. We work around this by:
# 1. Creating a fake systemctl that always succeeds
# 2. Installing the package normally (post-install now harmlessly no-ops)
# 3. Removing the fake systemctl after installation

FAKE_SYSTEMCTL=false
if ! pidof systemd > /dev/null 2>&1; then
    echo "Detected non-systemd environment (proot). Installing systemctl shim..."
    FAKE_SYSTEMCTL=true
    # Back up real systemctl if it exists
    if [ -f /usr/bin/systemctl ]; then
        mv /usr/bin/systemctl /usr/bin/systemctl.real
    fi
    # Create a no-op systemctl that always succeeds
    cat > /usr/bin/systemctl << 'SHIM_EOF'
#!/bin/bash
# Fake systemctl shim for proot environments (no systemd)
exit 0
SHIM_EOF
    chmod +x /usr/bin/systemctl
fi

if [ "$FAKE_SYSTEMCTL" = true ]; then
    # In proot, also skip triggers during install (setpriv fails in proot)
    dpkg --no-triggers -i /tmp/claimation.deb || true
    apt install --fix-broken -y || true
    dpkg --configure --pending || true
else
    dpkg -i /tmp/claimation.deb || true
    apt install -f -y
fi

# Restore real systemctl or remove shim
if [ "$FAKE_SYSTEMCTL" = true ]; then
    if [ -f /usr/bin/systemctl.real ]; then
        mv /usr/bin/systemctl.real /usr/bin/systemctl
    else
        rm -f /usr/bin/systemctl
    fi
    echo "Systemctl shim removed."
fi

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

    # --- Encryption Helper ---
    encrypt_pass() {
        local pass="$1"
        
        # Check if already encrypted (Heuristic: 24+ chars, Base64 with padding)
        # This prevents triple-encryption when passed from the Dashboard.
        if [[ "$pass" =~ ^[A-Za-z0-9+/]{22,}==?$ ]]; then
            echo -n "$pass"
            return
        fi

        local secret="DistroClaimationSecretKey2024!24/7"
        # Derive 32-byte key from SHA256 of secret
        local key=$(echo -n "$secret" | openssl dgst -sha256 -binary | xxd -p -c 32)
        local iv="00000000000000000000000000000000"
        echo -n "$pass" | openssl enc -aes-256-cbc -K "$key" -iv "$iv" -base64 -A
    }

    # Store Encrypted Password if provided
    CLAIM_PASS="${CLAIM_PASS:-}"
    if [ -n "$CLAIM_PASS" ]; then
        encrypt_pass "$CLAIM_PASS" > "$ZXCVBN_DIR/$FOLDER_NAME/claim_pass.txt"
    fi
else
    echo "WARN: CLAIM_USER not set. Claimation will require manual setup on first run."
fi

# 5c. Create Watchdog Service (replaces systemd for 24/7 persistence)
echo "Creating Claimation watchdog service..."
WRAPPERS_DIR="/usr/local/bin"
WATCHDOG_PATH="$WRAPPERS_DIR/claimation-watchdog"
WATCHDOG_PID_FILE="/tmp/claimation-watchdog.pid"

cat <<'WATCHDOG_EOF' > "$WATCHDOG_PATH"
#!/bin/bash
# Claimation Persistence Watchdog (Termux/Proot)
# Emulates systemd's 'restart-on-failure' behavior
# This script runs as a background daemon and keeps claimation alive 24/7.

PIDFILE="/tmp/claimation-watchdog.pid"
LOGFILE="/tmp/claimation-watchdog.log"

# Prevent duplicate watchdog instances
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Watchdog already running (PID $OLD_PID). Skipping."
        exit 0
    fi
fi

# Write our PID
echo $$ > "$PIDFILE"

echo "Claimation Watchdog started at $(date)" | tee -a "$LOGFILE"

cleanup() {
    rm -f "$PIDFILE"
    echo "Watchdog stopped at $(date)" >> "$LOGFILE"
    exit 0
}
trap cleanup EXIT INT TERM

while true; do
    # 1. Check/Start background daemon (updater)
    if ! pgrep -f "claimation.daemon" > /dev/null 2>&1; then
        echo "[$(date)] Starting claimation-daemon..." >> "$LOGFILE"
        claimation-daemon run >> "$LOGFILE" 2>&1 &
    fi
    
    # 2. Check/Start main app
    # Note: We skip update check here because the daemon handles it
    if ! pgrep -f "claimation run" > /dev/null 2>&1; then
        echo "[$(date)] Starting claimation-app..." >> "$LOGFILE"
        # Ensure DISPLAY is set (use Termux:X11 display :0 if available)
        export DISPLAY=:0
        claimation run --skip-update-check >> "$LOGFILE" 2>&1 &
    fi
    sleep 60
done
WATCHDOG_EOF

chmod +x "$WATCHDOG_PATH"

# 5d. Auto-start watchdog on EVERY proot login (not just XFCE desktop)
# This is the critical fix: .bashrc runs on every `proot-distro login debian`,
# so the watchdog starts whether or not you launch the XFCE desktop.
if ! grep -q "claimation-watchdog" /root/.bashrc 2>/dev/null; then
    cat >> /root/.bashrc << 'BASHRC_WATCHDOG_EOF'

# Claimation 24/7 Watchdog Auto-Start
# Automatically starts the watchdog in the background on every login.
# The watchdog prevents duplicate instances via PID file.
(nohup /usr/local/bin/claimation-watchdog > /dev/null 2>&1 &)
BASHRC_WATCHDOG_EOF
    echo "Watchdog auto-start added to .bashrc"
fi

# 5e. Also keep XFCE autostart for desktop sessions (belt and suspenders)
mkdir -p /root/.config/autostart
cat > /root/.config/autostart/claimation-watchdog.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Claimation Watchdog
Comment=Ensures Claimation runs 24/7
Exec=/usr/local/bin/claimation-watchdog
Icon=utilities-terminal
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# Remove old direct autostart if it exists (watchdog handles it now)
rm -f /root/.config/autostart/claimation.desktop

echo "--- [GUEST] Claimation automation complete (24/7 Ready) ---"
