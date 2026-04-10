#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_step "Step 4: Configuring WSL for Systemd support..."

# Check if systemd is already enabled
if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
    log_info "Enabling systemd in /etc/wsl.conf..."
    echo -e "[boot]\nsystemd=true" | sudo tee /etc/wsl.conf > /dev/null
    log_warn "Systemd enabled. A WSL restart will be required."
else
    log_success "Systemd is already enabled in /etc/wsl.conf."
fi

# Update ~/.bashrc with dynamic DISPLAY detection (IDEMPOTENT — won't duplicate)
if ! grep -q "# Dynamic X11 Display Detection" ~/.bashrc 2>/dev/null; then
    log_info "Injecting dynamic DISPLAY detection into ~/.bashrc..."
    cat >> ~/.bashrc << 'BASHRC_EOF'

# Dynamic X11 Display Detection (for WSL + XRDP)
# Automatically finds the active X11 display so GUI apps (google-chrome, etc.)
# work without manual DISPLAY configuration.
if [ -d /tmp/.X11-unix ]; then
    # Find the highest display number (XRDP uses :10, :11, :12...)
    DETECTED_DISPLAY=$(ls /tmp/.X11-unix/ | grep -oP 'X\K\d+' | sort -n | tail -1)
    if [ -n "$DETECTED_DISPLAY" ]; then
        export DISPLAY=:${DETECTED_DISPLAY}.0
    fi
fi
# Fallback: If no X11 socket found but Xvfb is running, use :99
if [ -z "$DISPLAY" ]; then
    if pgrep -x Xvfb > /dev/null 2>&1; then
        export DISPLAY=:99.0
    fi
fi
BASHRC_EOF
    log_success "Dynamic DISPLAY detection added to .bashrc."
else
    log_info "Dynamic DISPLAY detection already present in .bashrc. Skipping."
fi

log_success "WSL configuration complete."
