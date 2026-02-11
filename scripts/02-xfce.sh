#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_info "Step 2: Installing XFCE4 Desktop Environment..."
log_warn "This may take a few minutes depending on your internet speed."

sudo apt install -y xfce4 xfce4-goodies dbus-x11

log_success "XFCE4 installation complete."
