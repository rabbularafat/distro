#!/bin/bash
# unix-xfce/scripts/02-xfce.sh
source "$(dirname "$0")/utils.sh"

DISTRO=$(get_distro)
log_info "Step 2: Detected Distro: $DISTRO"

log_info "Installing XFCE4 Desktop Environment (this may take a while)..."
export DEBIAN_FRONTEND=noninteractive
apt install -y xfce4 xfce4-goodies

log_success "XFCE4 installation complete."
