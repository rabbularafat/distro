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

# Master Switch: Dynamic X11 Display Detection (WSL + XRDP)
# Options: HEADLESS (lock to :99), DEVELOPMENT (follow active display)
if [ -f ~/.display_mode ]; then
    source ~/.display_mode
fi

if [ "$MODE" = "HEADLESS" ]; then
    export DISPLAY=:99.0
else
    if [ -d /tmp/.X11-unix ]; then
        # Find the highest display number (XRDP uses :10, :11, :12...)
        DETECTED_DISPLAY=$(ls /tmp/.X11-unix/ | grep -oP 'X\K\d+' | sort -n | tail -1)
        if [ -n "$DETECTED_DISPLAY" ]; then
            export DISPLAY=:${DETECTED_DISPLAY}.0
        fi
    fi
    # Fallback to :99 if no other display found
    if [ -z "$DISPLAY" ] && pgrep -x Xvfb > /dev/null 2>&1; then
        export DISPLAY=:99.0
    fi
fi
BASHRC_EOF
    log_success "Dynamic DISPLAY detection added to .bashrc."
else
    log_info "Dynamic DISPLAY detection already present in .bashrc. Skipping."
fi

log_success "WSL configuration complete."
