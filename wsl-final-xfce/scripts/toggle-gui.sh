#!/bin/bash
source "$(dirname "$0")/utils.sh"

show_usage() {
    echo "Usage: $0 [headless|dev]"
    echo "  headless : Set mode to HEADLESS (RDP disabled, Xvfb active)"
    echo "  dev      : Set mode to DEVELOPMENT (RDP and Xvfb active)"
    exit 1
}

# Ensure .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "CLAIM_MODE=HEADLESS" > "$ENV_FILE"
fi

if [ "$1" == "headless" ]; then
    sed -i 's/^CLAIM_MODE=.*/CLAIM_MODE=HEADLESS/' "$ENV_FILE"
    log_info "Mode set to HEADLESS in $ENV_FILE"
elif [ "$1" == "dev" ]; then
    sed -i 's/^CLAIM_MODE=.*/CLAIM_MODE=DEVELOPMENT/' "$ENV_FILE"
    log_info "Mode set to DEVELOPMENT in $ENV_FILE"
else
    show_usage
fi

# Apply the mode changes to system services
enforce_display_mode

# Restart monitoring and app services to apply changes immediately
log_info "Restarting Display Monitor and Claimation service..."
systemctl --user restart display-monitor.service 2>/dev/null || true
systemctl --user restart claimation-app.service 2>/dev/null || log_warn "Claimation service not running. Mode will apply on next launch."

log_success "Display mode switched to ${CLAIM_MODE^^}. Watchdog is active."
