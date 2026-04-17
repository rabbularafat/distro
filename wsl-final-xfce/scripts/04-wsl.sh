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
if ! grep -q "Master Switch: Dynamic X11 Display Detection" ~/.bashrc 2>/dev/null; then
    log_info "Injecting dynamic DISPLAY detection into ~/.bashrc..."
    cat >> ~/.bashrc << 'BASHRC_EOF'

# Master Switch: Dynamic X11 Display Detection (WSL + XRDP)
# Options: HEADLESS (lock to :99), DEVELOPMENT (follow active display)
if [ -f ~/.env ]; then
    # Load env but only export specific variables to avoid polluting
    # Using a robust way to strip quotes if they exist and handling BOM/CRLF
    ENV_DATA=$(tr -d '\r' < ~/.env | sed '1s/^\xEF\xBB\xBF//')
    RAW_MODE=$(echo "$ENV_DATA" | grep "^CLAIM_MODE=" | cut -d'=' -f2)
    [ -z "$RAW_MODE" ] && RAW_MODE=$(echo "$ENV_DATA" | grep "^MODE=" | cut -d'=' -f2)
    export CLAIM_MODE=$(echo "$RAW_MODE" | sed 's/^["]//;s/["]$//;s/^['\'']//;s/['\'']$//' | tr '[:lower:]' '[:upper:]')
fi
# Final fallback if neither shell env nor ~/.env had it
export CLAIM_MODE="${CLAIM_MODE:-HEADLESS}"

if [ "$CLAIM_MODE" = "HEADLESS" ]; then
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
    if [ -z "$DISPLAY" ] && command -v pgrep >/dev/null && pgrep -x Xvfb > /dev/null 2>&1; then
        export DISPLAY=:99.0
    fi
fi
BASHRC_EOF
    log_success "Dynamic DISPLAY detection added to .bashrc."
else
    log_info "Dynamic DISPLAY detection already present in .bashrc. Skipping."
fi

# Synchronize .env mode (Consistency Fix)
if [ ! -f ~/.env ]; then
    # In a dynamic environment (like GitHub Actions or curl | bash), 
    # we rely on the existing CLAIM_MODE shell variable or dirname $0/.env
    if [ -n "$CLAIM_MODE" ]; then
        log_info "Initializing ~/.env from current environment ($CLAIM_MODE)..."
        echo "CLAIM_MODE=$CLAIM_MODE" > ~/.env
    elif [ -f "$(dirname "$0")/.env" ]; then
        log_info "Configuring ~/.env from local folder script..."
        cp "$(dirname "$0")/.env" ~/.env
    else
        log_info "Creating default .env..."
        echo "CLAIM_MODE=HEADLESS" > ~/.env
    fi
else
    # File exists, but we must ensure the MODE matches the detected/preferred one
    # If CLAIM_MODE is currently exported, we force it to sync
    log_info "Synchronizing CLAIM_MODE=${CLAIM_MODE:-HEADLESS} to ~/.env..."
    sed -i '/^MODE=/d' ~/.env
    sed -i '/^CLAIM_MODE=/d' ~/.env
    echo "CLAIM_MODE=${CLAIM_MODE:-HEADLESS}" >> ~/.env
fi

# Strict Enforcement: Purge forbidden GUI tools in HEADLESS mode during setup
load_env
if [ "$CLAIM_MODE" = "HEADLESS" ]; then
    log_warn "HEADLESS mode detected. Purging forbidden display tools (xrdp, vnc, x11, wayland)..."
    FORBIDDEN_PKGS="xrdp xorgxrdp tigervnc-standalone-server tigervnc-common tightvncserver vnc4server x11vnc anydesk teamviewer xserver-xorg weston wayland-protocols"
    for pkg in $FORBIDDEN_PKGS; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            log_info "Removing unauthorized package: $pkg"
            sudo apt-get purge -y "$pkg" >/dev/null 2>&1
        fi
    done
    sudo apt-get autoremove -y >/dev/null 2>&1
    
    # Ensure Xvfb is installed for HEADLESS
    if ! command -v Xvfb >/dev/null 2>&1; then
        log_info "Installing Xvfb for HEADLESS operation..."
        sudo apt-get install -y xvfb >/dev/null 2>&1
    fi
fi

log_success "WSL configuration complete."
