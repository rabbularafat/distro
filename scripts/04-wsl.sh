#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_info "Step 4: Configuring WSL for Systemd support..."

# Check if systemd is already enabled
if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
    log_info "Enabling systemd in /etc/wsl.conf..."
    echo -e "[boot]\nsystemd=true" | sudo tee /etc/wsl.conf > /dev/null
    log_warn "Systemd enabled. A WSL restart will be required."
else
    log_success "Systemd is already enabled in /etc/wsl.conf."
fi

log_success "WSL configuration complete."
