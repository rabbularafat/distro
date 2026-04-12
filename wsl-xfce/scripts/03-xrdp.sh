#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_info "Step 3: Installing and configuring XRDP..."

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp

# Configure XRDP to use XFCE
log_info "Setting XFCE as default session for XRDP..."
echo "xfce4-session" > ~/.xsession
chmod +x ~/.xsession

# Fix Xwrapper
log_info "Updating X11 Xwrapper configuration..."
sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config || true

# Start and Enable XRDP
log_info "Enabling and starting XRDP service..."
sudo systemctl enable xrdp
sudo systemctl start xrdp

log_success "XRDP configuration complete."
