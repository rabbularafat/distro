#!/bin/bash
# unix-xfce/scripts/02-xfce.sh
source "$(dirname "$0")/utils.sh"

DISTRO=$(get_distro)
log_info "Detected Distro: $DISTRO"

log_info "Installing XFCE4 Desktop Environment..."
apt install -y xfce4 xfce4-goodies dbus-x11

log_success "XFCE4 installation complete."
