#!/bin/bash
# unix-xfce/scripts/03-xrdp.sh
source "$(dirname "$0")/utils.sh"

log_info "Step 3: Installing and configuring XRDP..."

apt install -y xrdp

# Add xrdp to ssl-cert group to avoid permission issues with keys
if getent group ssl-cert >/dev/null; then
    usermod -a -G ssl-cert xrdp
fi

# Configure .xsession for the user who ran the script
REAL_USER=$SUDO_USER
if [ -z "$REAL_USER" ]; then REAL_USER=$(whoami); fi

log_info "Configuring .xsession for user: $REAL_USER"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
echo "xfce4-session" > "$USER_HOME/.xsession"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xsession"

# Fix X11 Permissions (often needed for XRDP)
if [ -f /etc/X11/Xwrapper.config ]; then
    sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config
fi

systemctl enable xrdp
systemctl restart xrdp

log_success "XRDP is now running and enabled."
log_info "Note: Ensure your firewall allows port 3389."
