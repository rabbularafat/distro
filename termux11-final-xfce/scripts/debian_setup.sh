#!/bin/bash

# Debian Guest Setup Script (Termux11-Final-XFCE)
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
CLAIMATION_VERSION="1.5.6"
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
    # 0. Check/Start privacy overlay.
    # Requires --shared-tmp so /tmp/.X11-unix/X0 is visible inside proot.
    # The watchdog itself is started with --shared-tmp by the Termux-side launcher.
    if [ -f /root/.claimation/.overlay_key ] && [ -x /usr/local/bin/.x11dpy ]; then
        OK=$(cat /root/.claimation/.overlay_key 2>/dev/null)
        # Only attempt if X11 socket is actually visible
        if [ -e /tmp/.X11-unix/X0 ]; then
            ST=$(/usr/local/bin/.x11dpy "$OK" status 2>/dev/null)
            if [ "$ST" != "1" ]; then
                echo "[$(date)] Starting privacy overlay..." >> "$LOGFILE"
                DISPLAY=:0 /usr/local/bin/.x11dpy "$OK" on >> "$LOGFILE" 2>&1 &
            fi
        fi
    fi

    # 1. Check/Start background daemon (updater)
    if ! pgrep -f "claimation.daemon" > /dev/null 2>&1; then
        echo "[$(date)] Starting claimation-daemon..." >> "$LOGFILE"
        claimation-daemon run >> "$LOGFILE" 2>&1 &
    fi

    # 2. Check/Start main app
    if ! pgrep -f "claimation run" > /dev/null 2>&1; then
        echo "[$(date)] Starting claimation-app..." >> "$LOGFILE"
        export DISPLAY=:0
        claimation run --skip-update-check >> "$LOGFILE" 2>&1 &
    fi
    sleep 30
done
WATCHDOG_EOF

chmod +x "$WATCHDOG_PATH"

# 5d. Auto-start watchdog on EVERY proot login (not just XFCE desktop)
# IMPORTANT: The Termux-side .bashrc hook must use --shared-tmp so the watchdog
# can see /tmp/.X11-unix/X0 and launch the privacy overlay correctly.
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

# ==============================================================================
# 6. Screen Privacy Overlay (Pure X11, input-transparent)
# ==============================================================================
echo "[6/6] Installing Screen Privacy Overlay..."

# Generate a secret auth key (32 random chars)
OVERLAY_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# Install the overlay command with an obscure name
cat > /usr/local/bin/.x11dpy << 'OVERLAY_PY_EOF'
#!/usr/bin/env python3
"""
X11 Privacy Overlay — Multi-Display Coverage (ULTRA-ROBUST)
=============================================
Protected by SHA-256 Auth.
Self-backgrounding via double-fork.
Always-on by default — use 'off' to temporarily disable.
"""

import os, sys, signal, hashlib, time, ctypes, ctypes.util, glob

PID_FILE = os.path.expanduser("~/.claimation/.x11dpy.pid")
AUTH_FILE = os.path.expanduser("~/.claimation/.x11auth")
LOG_FILE = os.path.expanduser("~/.claimation/overlay.log")

# X11 Constants
CWOverrideRedirect = 512
CWBackPixel = 2
ShapeInput = 2
ShapeSet = 0

class _XAttr(ctypes.Structure):
    _fields_ = [
        ("bg_pixmap", ctypes.c_ulong), ("bg_pixel", ctypes.c_ulong),
        ("brd_pixmap", ctypes.c_ulong), ("brd_pixel", ctypes.c_ulong),
        ("bit_grav", ctypes.c_int), ("win_grav", ctypes.c_int),
        ("backing", ctypes.c_int), ("bk_planes", ctypes.c_ulong),
        ("bk_pixel", ctypes.c_ulong), ("save_under", ctypes.c_int),
        ("ev_mask", ctypes.c_long), ("no_prop", ctypes.c_long),
        ("override", ctypes.c_int), ("cmap", ctypes.c_ulong), ("cursor", ctypes.c_ulong)
    ]

def _log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except: pass

def _hash(k): return hashlib.sha256(k.encode("utf-8")).hexdigest()
def _verify(k):
    try:
        with open(AUTH_FILE, "r") as f: return _hash(k) == f.read().strip()
    except FileNotFoundError: return False

def _set_key(k):
    os.makedirs(os.path.dirname(AUTH_FILE), exist_ok=True)
    with open(AUTH_FILE, "w") as f: f.write(_hash(k))
    os.chmod(AUTH_FILE, 0o600)

def _read_pid():
    try:
        with open(PID_FILE, "r") as f: return int(f.read().strip())
    except (FileNotFoundError, ValueError): return None

def _is_running(pid):
    if pid is None: return False
    try: os.kill(pid, 0); return True
    except OSError: return False

def _cleanup(*_a):
    _log("Stopping daemon...")
    try: os.remove(PID_FILE)
    except FileNotFoundError: pass
    sys.exit(0)

def _write_pid():
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f: f.write(str(os.getpid()))
    os.chmod(PID_FILE, 0o600)

def _discover_displays():
    displays = set()
    try:
        for sock in glob.glob("/tmp/.X11-unix/X*"):
            num = os.path.basename(sock).replace("X", "")
            if num.isdigit():
                displays.add(":" + num)
    except Exception: pass
    return list(displays)

def _load_x11():
    x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
    xext = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Xext") or "libXext.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XCreateSimpleWindow.restype = ctypes.c_ulong
    x11.XWhitePixel.restype = ctypes.c_ulong
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XNoOp.argtypes = [ctypes.c_void_p]
    return x11, xext

def _try_open_display(x11, display_name):
    """Attempt to open display across various potential Xauthority files."""
    auth_files = [
        os.environ.get("XAUTHORITY"),
        os.path.expanduser("~/.Xauthority"),
    ]
    # Add any .xauth* files in /tmp owned by current user
    try:
        uid = os.getuid()
        for f in glob.glob("/tmp/.xauth*"):
            try:
                if os.stat(f).st_uid == uid:
                    auth_files.append(f)
            except: pass
    except: pass

    original_auth = os.environ.get("XAUTHORITY")

    for auth in filter(None, auth_files):
        try:
            os.environ["XAUTHORITY"] = auth
            d = x11.XOpenDisplay(display_name.encode())
            if d:
                return d
        except: pass

    # Final try with nothing
    try:
        if "XAUTHORITY" in os.environ: del os.environ["XAUTHORITY"]
        d = x11.XOpenDisplay(display_name.encode())
        if d: return d
    except: pass

    # Restore
    if original_auth: os.environ["XAUTHORITY"] = original_auth
    return None

def _cover_display(x11, xext, display_name):
    try:
        d = _try_open_display(x11, display_name)
        if not d:
            _log(f"Failed to find authorization for {display_name}")
            return None

        s = x11.XDefaultScreen(ctypes.c_void_p(d))
        r = x11.XDefaultRootWindow(ctypes.c_void_p(d))
        w = x11.XDisplayWidth(ctypes.c_void_p(d), s)
        h = x11.XDisplayHeight(ctypes.c_void_p(d), s)
        wp = x11.XWhitePixel(ctypes.c_void_p(d), s)

        win = x11.XCreateSimpleWindow(ctypes.c_void_p(d), r, 0, 0, w, h, 0, 0, wp)
        a = _XAttr(); a.override = 1; a.bg_pixel = wp
        x11.XChangeWindowAttributes(ctypes.c_void_p(d), win, CWOverrideRedirect | CWBackPixel, ctypes.byref(a))

        # Input transparency
        xext.XShapeCombineRectangles(ctypes.c_void_p(d), ctypes.c_ulong(win), ShapeInput, 0, 0, None, 0, ShapeSet, 0)

        x11.XMapWindow(ctypes.c_void_p(d), win)
        x11.XRaiseWindow(ctypes.c_void_p(d), win)
        x11.XFlush(ctypes.c_void_p(d))

        _log(f"Successfully covered display {display_name}")
        return (d, win)
    except Exception as e:
        _log(f"Error covering {display_name}: {e}")
        return None

def _is_our_daemon(pid):
    """Verify a PID belongs to our .x11dpy daemon (not a recycled PID)."""
    if pid is None: return False
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline = f.read().replace(b"\x00", b" ").decode(errors="replace")
        return ".x11dpy" in cmdline or "x11dpy" in cmdline
    except: return False

def _daemon_main():
    signal.signal(signal.SIGTERM, _cleanup)
    signal.signal(signal.SIGINT, _cleanup)
    _write_pid()
    _log("Daemon started (v3.3 Termux)")

    x11 = None
    xext = None
    try:
        x11, xext = _load_x11()
    except Exception as e:
        _log(f"Library load failed: {e}")
        _cleanup()

    overlays = {}
    no_dpy_count = 0
    while True:
        try:
            current_displays = _discover_displays()

            # Wait up to 5 minutes for a display to appear (proot may start before X11)
            if not current_displays and not overlays:
                no_dpy_count += 1
                if no_dpy_count > 100:  # 100 * 3s = 5 minutes
                    _log("No X11 displays after 5 minutes. Exiting.")
                    _cleanup()
            else:
                no_dpy_count = 0

            # New displays
            for disp in current_displays:
                if disp not in overlays:
                    result = _cover_display(x11, xext, disp)
                    if result: overlays[disp] = result

            # Maintenance
            for disp, (dp, win) in list(overlays.items()):
                try:
                    # Keep on top
                    x11.XRaiseWindow(ctypes.c_void_p(dp), win)
                    x11.XFlush(ctypes.c_void_p(dp))
                except:
                    _log(f"Lost display {disp}")
                    try: x11.XCloseDisplay(ctypes.c_void_p(dp))
                    except: pass
                    del overlays[disp]

            # Cleanup gone displays
            stale = [d for d in overlays if d not in current_displays]
            for d in stale:
                try: x11.XCloseDisplay(ctypes.c_void_p(overlays[d][0]))
                except: pass
                del overlays[d]

        except Exception as e:
            _log(f"Loop error: {e}")

        time.sleep(3)

def _on():
    pid = _read_pid()
    # Use _is_our_daemon to avoid false positives from recycled PIDs
    if _is_running(pid) and _is_our_daemon(pid):
        print("Privacy Overlay: ALREADY RUNNING")
        return
    # Clean up stale PID file if process is not our daemon
    if pid is not None and not _is_our_daemon(pid):
        _log(f"Stale PID {pid} detected (recycled). Cleaning up.")
        try: os.remove(PID_FILE)
        except: pass
    # Warn if no X11 socket yet (daemon will keep retrying)
    if not glob.glob("/tmp/.X11-unix/X*"):
        _log("Warning: No X11 socket found yet - daemon will wait for display (need --shared-tmp).")
    try:
        pid = os.fork()
        if pid > 0:
            print("Privacy Overlay: ENABLED")
            return
    except OSError: sys.exit(1)
    os.setsid()
    try:
        pid2 = os.fork()
        if pid2 > 0: os._exit(0)
    except OSError: os._exit(1)

    # Fully detach
    sys.stdin.close()
    sys.stdout.close()
    sys.stderr.close()
    os.open(os.devnull, os.O_RDWR) # stdin
    os.dup2(0, 1) # stdout
    os.dup2(0, 2) # stderr

    _daemon_main()

def _off():
    pid = _read_pid()
    if _is_running(pid):
        try: os.kill(pid, signal.SIGTERM)
        except OSError: pass
        for _ in range(15):
            if not _is_running(pid): break
            time.sleep(0.2)
    try: os.remove(PID_FILE)
    except: pass
    print("Privacy Overlay: DISABLED")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        if len(sys.argv) == 2 and sys.argv[1] == "status":
            pid = _read_pid()
            # Accurate status: check PID AND verify it's our daemon
            running = _is_running(pid) and _is_our_daemon(pid)
            print("1" if running else "0")
            sys.exit(0)
        sys.exit(1)
    if sys.argv[1] == "--init": _set_key(sys.argv[2]); sys.exit(0)
    if not _verify(sys.argv[1]): sys.exit(1)
    a = sys.argv[2].lower()
    if a == "on": _on()
    elif a == "off": _off()
    elif a == "status":
        pid = _read_pid()
        running = _is_running(pid) and _is_our_daemon(pid)
        print("1" if running else "0")
    else: sys.exit(1)
OVERLAY_PY_EOF
chmod +x /usr/local/bin/.x11dpy

# Initialize the auth key
/usr/local/bin/.x11dpy --init "$OVERLAY_KEY"

# Save the key securely
mkdir -p /root/.claimation
echo "$OVERLAY_KEY" > /root/.claimation/.overlay_key
chmod 600 /root/.claimation/.overlay_key

# Auto-start overlay on proot login (same as watchdog)
if ! grep -q "x11dpy" /root/.bashrc 2>/dev/null; then
    cat >> /root/.bashrc << OVERLAY_BASHRC_EOF

# Privacy Overlay Auto-Start (Termux:X11 display :0)
_overlay_ensure_running() {
    # Only start if X11 socket is accessible (requires --shared-tmp)
    if [ ! -e /tmp/.X11-unix/X0 ]; then
        return
    fi
    if [ -f /root/.claimation/.overlay_key ] && [ -x /usr/local/bin/.x11dpy ]; then
        local OK=\$(cat /root/.claimation/.overlay_key 2>/dev/null)
        local ST=\$(/usr/local/bin/.x11dpy "\$OK" status 2>/dev/null)
        if [ "\$ST" = "0" ]; then
            DISPLAY=:0 /usr/local/bin/.x11dpy "\$OK" on &
            disown
        fi
    fi
}
_overlay_ensure_running
OVERLAY_BASHRC_EOF
    echo "Overlay auto-start added to .bashrc"
fi

# XFCE autostart for desktop sessions
cat > /root/.config/autostart/x11dpy.desktop << OVERLAY_DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=X11 Display Process
Exec=bash -c 'OK=\$(cat /root/.claimation/.overlay_key 2>/dev/null); /usr/local/bin/.x11dpy "\$OK" on'
Terminal=false
X-GNOME-Autostart-enabled=true
OVERLAY_DESKTOP_EOF

echo "Privacy Overlay installed and enabled (ON by default)."
echo "  Key: $OVERLAY_KEY"
echo "  Key saved to: /root/.claimation/.overlay_key"
echo "  Commands:"
echo "    .x11dpy <KEY> on       — Enable overlay"
echo "    .x11dpy <KEY> off      — Disable overlay"
echo "    .x11dpy <KEY> status   — Check status"
echo "  Overlay covers ALL displays (Termux:X11 :0 + VNC, etc.)."
echo "  Overlay is ALWAYS ON by default at startup."

echo "--- [GUEST] Claimation automation complete (24/7 Ready) ---"
