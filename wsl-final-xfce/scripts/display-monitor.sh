#!/bin/bash
# ==============================================================================
# Display Mode Monitor - Continuous Enforcement Watchdog
# ==============================================================================
# This script runs in the background to ensure that forbidden display tools
# (like RDP/VNC/TeamViewer) are not running when in HEADLESS mode.
# It also ensures only authorized tools are active in DEVELOPMENT mode.
# ==============================================================================

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="${SCRIPT_DIR}/utils.sh"

# Load shared utilities
if [ -f "$UTILS_PATH" ]; then
    source "$UTILS_PATH"
else
    echo "Error: utils.sh not found at ${UTILS_PATH}"
    exit 1
fi

log_info "Starting Display Monitor Watchdog..."
log_info "Monitoring config: ${ENV_FILE}"

# Initial enforcement
enforce_display_mode

# Continuous loop
while true; do
    # Sleep BEFORE the next check to avoid high CPU
    sleep 10
    
    # Reload env and re-enforce (this handles manual edits to .env)
    enforce_display_mode >/dev/null 2>&1
done
