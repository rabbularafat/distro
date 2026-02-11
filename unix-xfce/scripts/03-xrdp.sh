#!/bin/bash
# unix-xfce/scripts/03-xrdp.sh
source "$(dirname "$0")/utils.sh"

log_info "Installing and configuring XRDP for remote access..."

apt install -y xrdp

# Add xrdp to ssl-cert group to avoid permission issues with keys
if getent group ssl-cert >/dev/null; then
    usermod -a -G ssl-cert xrdp
fi

systemctl enable xrdp
systemctl restart xrdp

log_success "XRDP is now running and enabled."
log_info "Note: Ensure your firewall allows port 3389 if you are connecting remotely."
