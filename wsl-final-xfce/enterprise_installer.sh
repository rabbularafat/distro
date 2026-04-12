#!/bin/bash

# ==============================================================================
# WSL DEBIAN FINAL XFCE4 + XRDP + CLAIMATION ENTERPRISE INSTALLER v3.0
# ==============================================================================
# A professional, all-in-one script to transform WSL Debian into a desktop OS
# with automated Claimation deployment running 24/7 in the background.
#
# Usage:
#   export CLAIM_USER="your_custom_user"
#   export CLAIM_PASS="your_custom_pass"
#   export CLAIM_FB="optional_firebase_id"
#   curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/wsl-final-xfce/enterprise_installer.sh | bash
#
# After install: wsl --shutdown  (run from PowerShell, then reopen Debian)
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

# Automate installations (No prompts)
# NOTE: We use 'sudo DEBIAN_FRONTEND=noninteractive' on each apt call
# because plain 'export' does NOT survive through sudo.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Claimation .deb download URL
CLAIMATION_VERSION="1.5.3"
DEB_URL="https://github.com/rabbularafat/wsmation/releases/download/v${CLAIMATION_VERSION}/claimation_${CLAIMATION_VERSION}-1_all.deb"
DEB_FILE="/tmp/claimation.deb"

# Xvfb virtual display number (won't collide with XRDP's :10, :11, etc.)
XVFB_DISPLAY=":99"
XVFB_RESOLUTION="1280x1024x24"

# --- Logging Functions ---
log_step()    { echo -e "\n${BLUE}[STEP]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Claimation Configuration (from Environment Variables) ---
CLAIM_USER="${CLAIM_USER:-}"
CLAIM_PASS="${CLAIM_PASS:-}"
CLAIM_FB="${CLAIM_FB:-}"

if [ -z "$CLAIM_USER" ]; then
    log_warn "CLAIM_USER not provided. Claimation will require manual setup on first run."
fi

# ==============================================================================
# MODULE 0: Automation & Permissions
# ==============================================================================
setup_automation_permissions() {
    log_step "Configuring Zero-Touch Automation Permissions"
    
    # Configure Passwordless Sudo for the current user
    # This is critical for 24/7 background operation (systemd/reboots)
    log_info "Granting passwordless sudo to $(whoami)..."
    echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$(whoami)" >/dev/null
    sudo chmod 0440 "/etc/sudoers.d/$(whoami)"
    
    # Export non-interactive frontend for all child processes
    export DEBIAN_FRONTEND=noninteractive
    log_success "Automation permissions configured."
}

# --- Verification ---
check_env() {
    log_info "Verifying environment..."
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run as root. Run as a normal user with sudo privileges."
        exit 1
    fi
    if ! grep -qi "debian" /etc/os-release 2>/dev/null; then
        log_warn "This script is optimized for Debian. Continuing with caution..."
    fi
}

# ==============================================================================
# MODULE 1: System Update & Dependencies
# ==============================================================================
preconfigure_keyboard() {
    log_step "Preconfiguring keyboard layout (prevents interactive prompts)"
    echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | sudo debconf-set-selections
    echo 'keyboard-configuration keyboard-configuration/optionscode string ' | sudo debconf-set-selections
    echo 'tzdata tzdata/Areas select Etc' | sudo debconf-set-selections
    echo 'tzdata tzdata/Zones/Etc select UTC' | sudo debconf-set-selections
    echo 'locales locales/default_environment_locale select en_US.UTF-8' | sudo debconf-set-selections
    echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | sudo debconf-set-selections
    log_success "Keyboard and locale preconfigured."
}

install_system_deps() {
    log_step "Updating System Packages"
    # Use -o options to prevent prompts during package upgrades
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gnupg2 dbus-x11 coreutils
    log_success "System updated."
}

# ==============================================================================
# MODULE 2: FINAL XFCE4 Desktop Environment
# ==============================================================================
install_xfce() {
    log_step "Installing FINAL XFCE4 Desktop Environment"
    log_info "This might take a while..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        xfce4 xfce4-goodies
    log_success "FINAL XFCE4 installed."
}

# ==============================================================================
# MODULE 3: XRDP + Xvfb (Headless Display)
# ==============================================================================
install_xrdp_and_xvfb() {
    log_step "Installing XRDP + Xvfb (Virtual Framebuffer)"

    # Install XRDP for optional remote desktop + Xvfb for headless operation
    # xclip is required by pyperclip for clipboard operations on X11
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp xvfb xclip x11-xserver-utils python3-tk

    # --- .xsession: XRDP session startup with systemd DISPLAY injection ---
    log_info "Configuring .xsession with xhost and systemd persistence..."
    cat > ~/.xsession << 'XSESSION_EOF'
#!/bin/bash
# Allow local connections to X server (required for GUI apps)
xhost +local:

# Inject the XRDP display into systemd user environment
# This allows the Claimation service to use the real display when RDP is active
systemctl --user set-environment DISPLAY=$DISPLAY
systemctl --user set-environment XAUTHORITY=$XAUTHORITY

# Restart Claimation so it picks up the real display (instead of Xvfb)
systemctl --user restart claimation-app.service 2>/dev/null || true

# Start the desktop
xfce4-session
XSESSION_EOF
    chmod +x ~/.xsession

    # Xwrapper fix (allow non-console users to start X)
    sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config 2>/dev/null || true

    # Enable and start XRDP
    sudo systemctl enable xrdp
    sudo systemctl start xrdp

    # --- Create Xvfb systemd user service ---
    # This provides a virtual display for Claimation to run headlessly 24/7
    # pyautogui, pyperclip, Chrome — all work on Xvfb as it's a real X11 server
    log_info "Creating Xvfb systemd user service..."
    mkdir -p ~/.config/systemd/user

    cat > ~/.config/systemd/user/xvfb.service << XVFB_EOF
[Unit]
Description=Xvfb Virtual Framebuffer (Display ${XVFB_DISPLAY})
Documentation=man:Xvfb(1)

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb ${XVFB_DISPLAY} -screen 0 ${XVFB_RESOLUTION} -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
XVFB_EOF

    # --- Override claimation-app.service to depend on Xvfb ---
    # The .deb package ships /usr/lib/systemd/user/claimation-app.service
    # We create an override to:
    #   1. Make it depend on xvfb.service
    #   2. Set DISPLAY to the Xvfb display as default
    #   3. When RDP is active, .xsession overrides this with the real display
    log_info "Creating claimation-app service override..."
    mkdir -p ~/.config/systemd/user/claimation-app.service.d

    cat > ~/.config/systemd/user/claimation-app.service.d/override.conf << OVERRIDE_EOF
[Unit]
After=xvfb.service
Requires=xvfb.service

[Service]
Environment=DISPLAY=${XVFB_DISPLAY}
OVERRIDE_EOF

    # Pre-enable services via symlinks (systemd may not be running yet pre-restart)
    mkdir -p ~/.config/systemd/user/default.target.wants
    ln -sf ~/.config/systemd/user/xvfb.service ~/.config/systemd/user/default.target.wants/xvfb.service 2>/dev/null || true
    # The claimation-app.service symlink will be created after .deb install
    ln -sf /usr/lib/systemd/user/claimation-app.service ~/.config/systemd/user/default.target.wants/claimation-app.service 2>/dev/null || true

    log_success "XRDP + Xvfb configured."
}

# --- Password Encryption Helper ---
# Must match Laravel (PHP) and Claimation (Python) AES-256-CBC logic
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

# ==============================================================================
# MODULE 4: WSL Optimizations
# ==============================================================================
configure_wsl() {
    log_step "Optimizing WSL Configuration"

    # Enable Systemd (required for services to persist)
    if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
        log_info "Enabling Systemd support..."
        echo -e "[boot]\nsystemd=true" | sudo tee /etc/wsl.conf > /dev/null
        RESTART_REQUIRED=true
    else
        log_info "Systemd already enabled."
        RESTART_REQUIRED=false
    fi

    # Inject dynamic DISPLAY detection into ~/.bashrc (IDEMPOTENT)
    if ! grep -q "# Dynamic X11 Display Detection" ~/.bashrc 2>/dev/null; then
        log_info "Injecting dynamic DISPLAY detection into ~/.bashrc..."
        cat >> ~/.bashrc << 'BASHRC_EOF'

# Dynamic X11 Display Detection (for WSL + XRDP)
# Automatically finds the active X11 display so GUI apps (google-chrome, etc.)
# work without manual DISPLAY configuration.
if [ -d /tmp/.X11-unix ]; then
    # Find the highest display number (XRDP uses :10, :11, :12...)
    DETECTED_DISPLAY=$(ls /tmp/.X11-unix/ | grep -oP 'X\K\d+' | sort -n | tail -1)
    if [ -n "$DETECTED_DISPLAY" ]; then
        export DISPLAY=:${DETECTED_DISPLAY}.0
    fi
fi
# Fallback: If no X11 socket found but Xvfb is running, use :99
if [ -z "$DISPLAY" ]; then
    if pgrep -x Xvfb > /dev/null 2>&1; then
        export DISPLAY=:99.0
    fi
fi
BASHRC_EOF
        log_success "Dynamic DISPLAY detection added to .bashrc."
    else
        log_info "Dynamic DISPLAY detection already present in .bashrc."
    fi
}

# ==============================================================================
# MODULE 5: Claimation Installation & Automation
# ==============================================================================
install_claimation() {
    log_step "Installing and Automating Claimation"

    # 1. Download and Install the .deb package
    log_info "Downloading Claimation v${CLAIMATION_VERSION}..."
    wget -q --show-progress -O "$DEB_FILE" "$DEB_URL"

    log_info "Installing Claimation package..."
    sudo dpkg -i "$DEB_FILE" || true
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y

    # Clean up downloaded .deb
    rm -f "$DEB_FILE"

    # 1b. Apply Hotfix to installed app.py (Solve Permission/Status issues)
    # ---------------------------------------------------------------
    log_info "Applying automated hotfixes to installed Claimation code..."
    APP_PY="/usr/lib/claimation/claimation/app.py"

    if [ -f "$APP_PY" ]; then
        # Fix Status Path Logic (check for write access instead of just existence)
        sudo sed -i 's/if os.geteuid() == 0 or os.path.exists(STATUS_DIR):/if os.path.exists(STATUS_DIR) and os.access(STATUS_DIR, os.W_OK):/' "$APP_PY"
        
        # Fix startup sync fallback (remove the fallback to read-only source path)
        sudo sed -i 's/initial_ext_path = get_extension_source_path()/initial_ext_path = None/' "$APP_PY"
        
        log_success "Hotfixes applied successfully."
    else
        log_warn "Could not find app.py at $APP_PY. Skipping hotfix."
    fi

    # 2. Pre-configure Claimation profile (BYPASS interactive setup)
    # ---------------------------------------------------------------
    # How it works (from app.py get_this_device_name()):
    #   - Claimation checks ~/.config/chromium-browser/ZxcvbnPkData/
    #   - If ANY subfolder exists → it uses that folder name as the device
    #   - It reads firebase_id.txt from inside that folder
    #   - The interactive username/password prompt is SKIPPED entirely
    # ---------------------------------------------------------------
    if [ -n "$CLAIM_USER" ]; then
        log_info "Pre-configuring Claimation profile for '${CLAIM_USER}'..."
        PROFILE_DIR="$HOME/.config/chromium-browser/ZxcvbnPkData/$CLAIM_USER"
        mkdir -p "$PROFILE_DIR"

        # Store Firebase ID if provided
        if [ -n "$CLAIM_FB" ]; then
            echo "$CLAIM_FB" > "$PROFILE_DIR/firebase_id.txt"
            log_info "Firebase ID stored."
        fi

        if [ -n "$CLAIM_PASS" ]; then
            encrypt_pass "$CLAIM_PASS" > "$PROFILE_DIR/claim_pass.txt"
        fi

        log_success "Profile pre-configured. Interactive setup will be bypassed."
    else
        log_warn "No CLAIM_USER set. You'll need to run 'claimation run' manually for first-time setup."
    fi

    # 3. FINAL XFCE Autostart (Desktop session fallback)
    mkdir -p ~/.config/autostart
    cat > ~/.config/autostart/claimation.desktop << 'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=Claimation
Exec=claimation run
Icon=utilities-terminal
Terminal=false
X-GNOME-Autostart-enabled=true
AUTOSTART_EOF

    # 4. Enable lingering (runs user services even when not logged in)
    log_info "Enabling user lingering for 24/7 operation..."
    sudo loginctl enable-linger "$(whoami)" 2>/dev/null || true

    # 5. Pre-enable services
    # (systemd might not be running yet — it starts after wsl --shutdown)
    mkdir -p ~/.config/systemd/user/default.target.wants
    
    # User-level app service
    ln -sf /usr/lib/systemd/user/claimation-app.service \
        ~/.config/systemd/user/default.target.wants/claimation-app.service 2>/dev/null || true
    
    # System-level updater service (requires sudo)
    sudo systemctl enable claimation-updater.service 2>/dev/null || true

    log_success "Claimation installed and automated for 24/7 background operation."
}

# ==============================================================================
# MODULE 6: Screen Privacy Overlay
# ==============================================================================
install_screen_overlay() {
    log_step "Installing Screen Privacy Overlay"

    # --- Generate a secret auth key (32 random chars) ---
    OVERLAY_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

    # --- Install the overlay command with an obscure name ---
    log_info "Creating privacy overlay..."
    sudo tee /usr/local/bin/.x11dpy > /dev/null << 'OVERLAY_PY_EOF'
#!/usr/bin/env python3
"""X11 Display Process — protected screen overlay."""
import os, sys, signal, hashlib, ctypes, ctypes.util
PID_FILE = os.path.expanduser("~/.claimation/.x11dpy.pid")
AUTH_FILE = os.path.expanduser("~/.claimation/.x11auth")
def _hash(k): return hashlib.sha256(k.encode("utf-8")).hexdigest()
def _verify(k):
    try:
        with open(AUTH_FILE, "r") as f: return _hash(k) == f.read().strip()
    except FileNotFoundError: return False
def _set_key(k):
    os.makedirs(os.path.dirname(AUTH_FILE), exist_ok=True)
    with open(AUTH_FILE, "w") as f: f.write(_hash(k))
    os.chmod(AUTH_FILE, 0o600)
def _write_pid():
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f: f.write(str(os.getpid()))
    os.chmod(PID_FILE, 0o600)
def _read_pid():
    try:
        with open(PID_FILE, "r") as f: return int(f.read().strip())
    except (FileNotFoundError, ValueError): return None
def _is_running(pid):
    if pid is None: return False
    try: os.kill(pid, 0); return True
    except OSError: return False
def _cleanup(*_a):
    try: os.remove(PID_FILE)
    except FileNotFoundError: pass
    sys.exit(0)
def _xshape(root):
    try:
        x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
        xext = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Xext") or "libXext.so.6")
        d = x11.XOpenDisplay(os.environ.get("DISPLAY", ":99").encode())
        if not d: return False
        xext.XShapeCombineRectangles(
            ctypes.c_void_p(d), ctypes.c_ulong(root.winfo_id()), ctypes.c_int(2),
            ctypes.c_int(0), ctypes.c_int(0), None,
            ctypes.c_int(0), ctypes.c_int(0), ctypes.c_int(0))
        x11.XFlush(ctypes.c_void_p(d))
        return True
    except Exception: return False
def _on():
    if _is_running(_read_pid()): return
    try: import tkinter as tk
    except ImportError: sys.exit(1)
    if "DISPLAY" not in os.environ: os.environ["DISPLAY"] = ":99"
    signal.signal(signal.SIGTERM, _cleanup); signal.signal(signal.SIGINT, _cleanup)
    _write_pid()
    try:
        root = tk.Tk(); root.title("x11dpy")
        root.withdraw()
        root.overrideredirect(True)
        root.attributes("-fullscreen", True); root.attributes("-topmost", True)
        root.configure(bg="white")
        root.update_idletasks()
        _xshape(root)
        root.deiconify(); root.update()
        root.mainloop()
    except Exception: _cleanup()
def _off():
    pid = _read_pid()
    if not _is_running(pid): return
    try: os.kill(pid, signal.SIGTERM)
    except OSError: pass
    try: os.remove(PID_FILE)
    except FileNotFoundError: pass
def _st():
    pid = _read_pid()
    if _is_running(pid): print("1")
    else:
        print("0")
        try: os.remove(PID_FILE)
        except FileNotFoundError: pass
if __name__ == "__main__":
    if len(sys.argv) < 3: sys.exit(1)
    if sys.argv[1] == "--init" and len(sys.argv) == 3: _set_key(sys.argv[2]); sys.exit(0)
    if not _verify(sys.argv[1]): sys.exit(1)
    a = sys.argv[2].lower()
    if a == "on": _on()
    elif a == "off": _off()
    elif a == "status": _st()
    else: sys.exit(1)
OVERLAY_PY_EOF
    sudo chmod +x /usr/local/bin/.x11dpy

    # --- Initialize the auth key ---
    /usr/local/bin/.x11dpy --init "$OVERLAY_KEY"

    # --- Save the key securely ---
    mkdir -p ~/.claimation
    echo "$OVERLAY_KEY" > ~/.claimation/.overlay_key
    chmod 600 ~/.claimation/.overlay_key

    # --- Create systemd user service (contains key for auto-start) ---
    log_info "Creating overlay systemd service..."
    mkdir -p ~/.config/systemd/user

    cat > ~/.config/systemd/user/x11dpy.service << OVERLAY_SVC_EOF
[Unit]
Description=X11 Display Process
After=xvfb.service
Requires=xvfb.service

[Service]
Type=simple
Environment=DISPLAY=${XVFB_DISPLAY}
ExecStart=/usr/local/bin/.x11dpy ${OVERLAY_KEY} on
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
OVERLAY_SVC_EOF

    # Lock down the service file (contains the key)
    chmod 600 ~/.config/systemd/user/x11dpy.service

    # Pre-enable the service
    mkdir -p ~/.config/systemd/user/default.target.wants
    ln -sf ~/.config/systemd/user/x11dpy.service \
        ~/.config/systemd/user/default.target.wants/x11dpy.service 2>/dev/null || true

    log_success "Screen Privacy Overlay installed and enabled."
    log_info "  Secret key: ${OVERLAY_KEY}"
    log_info "  Key saved to: ~/.claimation/.overlay_key"
}


# ==============================================================================
# FINAL OUTPUT
# ==============================================================================
print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}✅ INSTALLATION COMPLETE!${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"

    echo ""
    echo -e "${YELLOW}🚨 REQUIRED: Restart WSL once to activate systemd${NC}"
    echo -e "   Run this in ${WHITE}Windows PowerShell${NC}:"
    echo -e "   ${MAGENTA}wsl --shutdown${NC}"
    echo -e "   Then reopen your Debian terminal."

    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}What happens after restart:${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Xvfb starts automatically (virtual display :99)       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Claimation starts automatically (24/7 background)     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Screen Privacy Overlay active (hides work)            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Auto-updater daemon runs as system service            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} No Remote Desktop Connection needed!                  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Useful commands:${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${MAGENTA}claimation status${NC}        — Check if running             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${MAGENTA}systemctl --user status claimation-app${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${MAGENTA}systemctl --user status xvfb${NC}                            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${MAGENTA}google-chrome${NC}            — Just works! (auto DISPLAY)   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${WHITE}Optional RDP access:${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BLUE}ip addr | grep eth0${NC}   — Get your WSL IP                ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    Connect via mstsc with your Linux credentials         ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

    if [ -n "$CLAIM_USER" ]; then
        echo ""
        echo -e "  ${GREEN}✅ Claimation Profile:${NC} $CLAIM_USER (auto-configured)"
    fi
    echo ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
clear
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│   WSL DEBIAN FINAL XFCE4 + CLAIMATION ENTERPRISE INSTALLER   │${NC}"
echo -e "${CYAN}│                       v3.0                              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

check_env
setup_automation_permissions
preconfigure_keyboard
install_system_deps
install_xfce
install_xrdp_and_xvfb
configure_wsl
install_claimation
install_screen_overlay
print_summary
