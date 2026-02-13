#!/bin/bash

# WSL Debian XFCE Installer - Bootstrap Script
# This script clones the repository and starts the main setup.

set -e

# Configuration
REPO_URL="https://github.com/rabbularafat/distro.git"
INSTALL_DIR="$HOME/.wsl-xfce-installer"

echo "===================================================="
echo "   WSL XFCE Installer - Initializing...            "
echo "===================================================="

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Git not found. Installing git..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
fi

# Clone or Update the installer
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installer files..."
    cd "$INSTALL_DIR" && git pull
else
    echo "Cloning installer repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Run the setup
cd "$INSTALL_DIR/wsl-xfce"
chmod +x setup.sh scripts/*.sh
./setup.sh
