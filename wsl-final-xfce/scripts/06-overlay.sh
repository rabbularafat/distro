#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_step "Step 6: Installing Screen Privacy Overlay..."

# No extra dependencies — uses pure Xlib via Python ctypes
# (libX11 and libXext are already installed with XFCE/Xvfb)

# --- Generate a secret auth key ---
OVERLAY_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# --- Install the overlay command with an obscure name ---
log_info "Installing privacy overlay..."
sudo cp "$(dirname "$0")/overlay.py" /usr/local/bin/.x11dpy
sudo chmod +x /usr/local/bin/.x11dpy

# --- Initialize the auth key ---
/usr/local/bin/.x11dpy --init "$OVERLAY_KEY"

# --- Save the key securely ---
mkdir -p ~/.claimation
echo "$OVERLAY_KEY" > ~/.claimation/.overlay_key
chmod 600 ~/.claimation/.overlay_key

# --- Create systemd user service (always enabled by default) ---
# NOTE: No DISPLAY env needed — the daemon auto-discovers ALL displays
log_info "Creating overlay systemd service..."
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/x11dpy.service << OVERLAY_SVC_EOF
[Unit]
Description=X11 Display Process
After=xvfb.service
Requires=xvfb.service

[Service]
Type=forking
ExecStart=/usr/local/bin/.x11dpy ${OVERLAY_KEY} on
ExecStop=/usr/local/bin/.x11dpy ${OVERLAY_KEY} off
PIDFile=%h/.claimation/.x11dpy.pid
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
OVERLAY_SVC_EOF

# Lock down the service file
chmod 600 ~/.config/systemd/user/x11dpy.service

# Pre-enable the service (overlay ON by default at boot)
mkdir -p ~/.config/systemd/user/default.target.wants
ln -sf ~/.config/systemd/user/x11dpy.service \
    ~/.config/systemd/user/default.target.wants/x11dpy.service 2>/dev/null || true

log_success "Screen Privacy Overlay installed and enabled (ON by default)."
log_info "  Your secret key: ${OVERLAY_KEY}"
log_info "  Key saved to: ~/.claimation/.overlay_key"
log_info "  Commands:"
log_info "    .x11dpy <KEY> on       — Enable overlay (instant)"
log_info "    .x11dpy <KEY> off      — Disable overlay (instant)"
log_info "    .x11dpy <KEY> status   — Check status"
log_info "  Overlay covers ALL displays (Xvfb + XRDP sessions)."
log_info "  Overlay is ALWAYS ON by default at startup."
