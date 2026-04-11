#!/bin/bash

# This script runs INSIDE the Proot Debian environment
set -e

# Automate installations (No prompts)
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Pre-configure keyboard and timezone to prevent interactive prompts
# These are mapped to English (US) by default as requested.
echo 'keyboard-configuration keyboard-configuration/layoutcode string us' | debconf-set-selections 2>/dev/null || true
echo 'keyboard-configuration keyboard-configuration/layout select English (US)' | debconf-set-selections 2>/dev/null || true
echo 'keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)' | debconf-set-selections 2>/dev/null || true
echo 'keyboard-configuration keyboard-configuration/variant select English (US)' | debconf-set-selections 2>/dev/null || true
echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections 2>/dev/null || true
echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections 2>/dev/null || true

echo "Updating Debian..."
apt update && apt upgrade -y
apt install sudo nano wget curl xfce4 xfce4-goodies dbus-x11 tigervnc-standalone-server -y

# Install Web Browser (Chromium) + Fonts
echo "Installing Chromium and system fonts..."
apt install chromium fonts-noto-core fonts-noto-color-emoji -y

# Chromium requires --no-sandbox in proot (no kernel sandboxing support)
# Inject the flag globally so every launch method works automatically
mkdir -p /etc/chromium.d
echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox"' > /etc/chromium.d/proot-flags

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

# Configure Chromium as default web browser for XFCE
echo "Setting Chromium as default web browser..."
mkdir -p "$USER_HOME/.config/xfce4"
cat <<EOF > "$USER_HOME/.config/xfce4/helpers.rc"
WebBrowser=chromium
EOF
chown -R remote:remote "$USER_HOME/.config/xfce4"

# Set system-wide default browser via alternatives
update-alternatives --set x-www-browser /usr/bin/chromium 2>/dev/null || true
update-alternatives --set gnome-www-browser /usr/bin/chromium 2>/dev/null || true

echo "Debian guest configuration complete."
