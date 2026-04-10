#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_step "Step 5: Installing and automating Claimation..."

# 1. Download and Install Claimation .deb
log_info "Downloading Claimation v${CLAIMATION_VERSION}..."
wget -q --show-progress -O "$DEB_FILE" "$DEB_URL"

log_info "Installing Claimation package..."
sudo dpkg -i "$DEB_FILE" || true
sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y

# Clean up downloaded .deb
rm -f "$DEB_FILE"

# 2. Pre-configure Claimation profile (BYPASS interactive setup)
# ---------------------------------------------------------------
# How it works (from claimation/app.py → get_this_device_name()):
#   - Claimation checks ~/.config/chromium-browser/ZxcvbnPkData/
#   - If ANY subfolder exists → uses that folder name as the device name
#   - Reads firebase_id.txt from inside that folder for the Firebase ID
#   - The interactive username/password prompt is COMPLETELY SKIPPED
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

    log_success "Profile pre-configured. Interactive setup will be bypassed."
else
    log_warn "CLAIM_USER not set. You'll need to run 'claimation run' manually for first-time setup."
fi

# 3. Enable Lingering (runs user services even when not logged in — 24/7 operation)
log_info "Enabling user lingering for 24/7 operation..."
sudo loginctl enable-linger "$(whoami)" 2>/dev/null || true

# 4. Set up XFCE autostart (desktop session fallback)
log_info "Setting up XFCE autostart for Claimation..."
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

# 5. Pre-enable the systemd user service via symlink
# (systemd might not be running yet before wsl --shutdown)
log_info "Pre-enabling Claimation systemd user service..."
mkdir -p ~/.config/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/claimation-app.service \
    ~/.config/systemd/user/default.target.wants/claimation-app.service 2>/dev/null || true

log_success "Claimation installation and automation complete."
