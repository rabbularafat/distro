#!/bin/bash

# Debian Guest Setup Script (Termux11-XFCE)
set -e

echo "--- [GUEST] Starting Debian internal configuration ---"

# 1. Update Debian
echo "[1/4] Updating Debian guest guest repositories..."
apt update && apt upgrade -y

# 2. Install Desktop Components
echo "[2/4] Installing XFCE4, Terminal, and Chromium..."
apt install sudo nano wget curl xfce4 xfce4-goodies dbus-x11 -y
apt install chromium fonts-noto-core fonts-noto-color-emoji -y

# 3. Chromium Sandboxing Fix (proot doesn't support kernel sandboxing)
echo "[3/4] Configuring Chromium flags for proot support..."
mkdir -p /etc/chromium.d
echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox"' > /etc/chromium.d/proot-flags

# Set Chromium as default browser
update-alternatives --set x-www-browser /usr/bin/chromium 2>/dev/null || true
update-alternatives --set gnome-www-browser /usr/bin/chromium 2>/dev/null || true

# 4. User and Environment Configuration
echo "[4/4] Finalizing environment settings..."

# No VNC login needed anymore, but we can still set up 'remote' user if the user wants.
# For now, we'll ensure that the root user can launch the desktop directly as per the script.

# Fix DBUS issues for XFCE
mkdir -p /run/dbus
dbus-uuidgen > /etc/machine-id || true

echo "--- [GUEST] Configuration complete ---"
