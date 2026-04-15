#!/bin/bash
# ==============================================================================
# GUI Mode Switcher for WSL Final XFCE
# Usage: ./toggle-gui.sh [headless|dev]
# ==============================================================================

MODE_FILE="$HOME/.display_mode"

show_usage() {
    echo "Usage: $0 [headless|dev]"
    echo "  headless : Set mode to HEADLESS (runs in background on :99)"
    echo "  dev      : Set mode to DEVELOPMENT (runs on active RDP screen)"
    exit 1
}

if [ "$1" == "headless" ]; then
    echo 'MODE="HEADLESS"' > "$MODE_FILE"
    echo "Mode set to HEADLESS. Software will run in the background."
elif [ "$1" == "dev" ]; then
    echo 'MODE="DEVELOPMENT"' > "$MODE_FILE"
    echo "Mode set to DEVELOPMENT. Software will follow your RDP display."
else
    show_usage
fi

# Restart the service to apply changes immediately
echo "Restarting Claimation service..."
systemctl --user restart claimation-app.service 2>/dev/null || echo "Service not running. It will use the new mode on next start."

echo "Done! If you switched to 'dev', please ensure you are logged in via RDP."
