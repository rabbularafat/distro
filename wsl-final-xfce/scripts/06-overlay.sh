#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_step "Step 6: Installing Screen Privacy Overlay..."

# --- Dependencies ---
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-tk

# --- Generate a secret auth key ---
# This key is required to enable/disable the overlay.
# Without it, no one can turn the overlay off.
OVERLAY_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# --- Install the overlay command with an obscure name ---
log_info "Installing privacy overlay..."
sudo cp "$(dirname "$0")/overlay.py" /usr/local/bin/.x11dpy
sudo chmod +x /usr/local/bin/.x11dpy

# --- Initialize the auth key ---
/usr/local/bin/.x11dpy --init "$OVERLAY_KEY"

# --- Save the key for the user (secure location) ---
mkdir -p ~/.claimation
echo "$OVERLAY_KEY" > ~/.claimation/.overlay_key
chmod 600 ~/.claimation/.overlay_key

# --- Create systemd user service ---
log_info "Creating overlay systemd service..."
mkdir -p ~/.config/systemd/user

OVERLAY_DISPLAY="${XVFB_DISPLAY:-:99}"

cat > ~/.config/systemd/user/x11dpy.service << OVERLAY_SVC_EOF
[Unit]
Description=X11 Display Process
After=xvfb.service
Requires=xvfb.service

[Service]
Type=simple
Environment=DISPLAY=${OVERLAY_DISPLAY}
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
log_info "  Your secret key: ${OVERLAY_KEY}"
log_info "  Key saved to: ~/.claimation/.overlay_key"
log_info "  Commands:"
log_info "    .x11dpy <KEY> on       — Enable overlay"
log_info "    .x11dpy <KEY> off      — Disable overlay"
log_info "    .x11dpy <KEY> status   — Check status"
log_info "  Without the correct key, commands silently fail."
