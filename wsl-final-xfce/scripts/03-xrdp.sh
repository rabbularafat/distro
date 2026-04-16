#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_step "Step 3: Installing and configuring XRDP + Xvfb..."

# Install XRDP + Xvfb + X11 utilities
# xclip: required by pyperclip for clipboard operations
# xvfb: virtual framebuffer for headless GUI (pyautogui, Chrome work on it)
# x11-xserver-utils: provides xhost command
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp xvfb xclip x11-xserver-utils

# Configure XRDP session with systemd DISPLAY injection
log_info "Setting up .xsession with xhost and systemd persistence..."
cat > ~/.xsession << 'XSESSION_EOF'
#!/bin/bash
# Allow local connections to X server
xhost +local: >/dev/null 2>&1

# Load display mode preference
[ -f ~/.env ] && source ~/.env
CLAIM_MODE="${CLAIM_MODE:-HEADLESS}"

# If in DEVELOPMENT mode, hijack the display for GUI apps
if [ "$CLAIM_MODE" = "DEVELOPMENT" ]; then
    # Inject the XRDP display into systemd user environment
    systemctl --user set-environment DISPLAY=$DISPLAY
    systemctl --user set-environment XAUTHORITY=$XAUTHORITY

    # Restart Claimation to pick up the real display
    systemctl --user restart claimation-app.service 2>/dev/null || true
fi

# Start the desktop
xfce4-session
XSESSION_EOF
chmod +x ~/.xsession

# Fix Xwrapper
log_info "Updating X11 Xwrapper configuration..."
sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config 2>/dev/null || true

# Start and Enable XRDP
log_info "Enabling and starting XRDP service..."
sudo systemctl enable xrdp
sudo systemctl start xrdp

# --- Create Xvfb systemd user service ---
# Xvfb is a REAL X11 server (renders pixels in RAM). It supports:
#   - pyautogui.moveTo(), click(), press() (via X11 XTest extension)
#   - pyperclip (via xclip on X11)
#   - Chrome/Chromium rendering
#   - All X11 GUI applications
# The only difference: no physical monitor output.
log_info "Creating Xvfb systemd user service (display ${XVFB_DISPLAY})..."
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

# Override claimation-app.service to depend on Xvfb
log_info "Creating claimation-app service override (depends on Xvfb)..."
mkdir -p ~/.config/systemd/user/claimation-app.service.d

cat > ~/.config/systemd/user/claimation-app.service.d/override.conf << OVERRIDE_EOF
[Unit]
After=xvfb.service
Requires=xvfb.service

[Service]
Environment=DISPLAY=${XVFB_DISPLAY}
OVERRIDE_EOF

# --- Create Display Monitor Watchdog service ---
log_info "Creating Display Monitor systemd user service..."
mkdir -p ~/.local/bin
cp "$(dirname "$0")/display-monitor.sh" ~/.local/bin/display-monitor.sh 2>/dev/null
chmod +x ~/.local/bin/display-monitor.sh

cat > ~/.config/systemd/user/display-monitor.service << MONITOR_EOF
[Unit]
Description=Display Mode Monitor Watchdog
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash %h/.local/bin/display-monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=display-monitor

[Install]
WantedBy=default.target
MONITOR_EOF

# Pre-enable services via symlinks (systemd may not be running yet)
mkdir -p ~/.config/systemd/user/default.target.wants
ln -sf ~/.config/systemd/user/xvfb.service ~/.config/systemd/user/default.target.wants/xvfb.service 2>/dev/null || true
ln -sf ~/.config/systemd/user/display-monitor.service ~/.config/systemd/user/default.target.wants/display-monitor.service 2>/dev/null || true

# Initialize .env if it doesn't exist
if [ ! -f ~/.env ]; then
    log_info "Initializing .env with default CLAIM_MODE=HEADLESS..."
    echo "CLAIM_MODE=HEADLESS" > ~/.env
fi

# Final enforcement based on current/default mode
enforce_display_mode

log_success "XRDP + Xvfb + Monitor configuration complete."
