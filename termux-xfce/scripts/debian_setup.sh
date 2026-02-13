#!/bin/bash

# This script runs INSIDE the Proot Debian environment
set -e

echo "Updating Debian..."
apt update && apt upgrade -y
apt install sudo nano wget curl xfce4 xfce4-goodies dbus-x11 tigervnc-standalone-server -y

# User Setup
if ! id "remote" &>/dev/null; then
    echo "Creating user 'remote'..."
    adduser --disabled-password --gecos "" remote
    echo "remote:1234" | chpasswd
    usermod -aG sudo remote
    echo "Default password for 'remote' is: 1234"
fi

# Configure Sudoers
echo "remote ALL=(ALL:ALL) ALL" > /etc/sudoers.d/remote
chmod 440 /etc/sudoers.d/remote

# Configure VNC for the remote user
USER_HOME="/home/remote"
mkdir -p "$USER_HOME/.vnc"
mkdir -p "$USER_HOME/.config/tigervnc"

cat <<EOF > "$USER_HOME/.vnc/xstartup"
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF

chmod +x "$USER_HOME/.vnc/xstartup"
chown -R remote:remote "$USER_HOME/.vnc"
chown -R remote:remote "$USER_HOME/.config/tigervnc"

echo "Debian guest configuration complete."
