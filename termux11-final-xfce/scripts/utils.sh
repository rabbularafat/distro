#!/bin/bash

# ==============================================================================
# Shared Utilities for Termux11-Final-XFCE
# ==============================================================================

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Display Mode Settings (.env)
# In Termux, we check for .env in the user's home (usually /root in proot)
export ENV_FILE="$HOME/.env"

# Forbidden display tools that must not run in HEADLESS mode
FORBIDDEN_TOOLS=("xrdp" "Xvnc" "vncserver" "teamviewer" "anydesk" "remotely")

load_env() {
    if [ -f "$ENV_FILE" ]; then
        # Load variables from .env, excluding comments and empty lines
        set -a
        source "$ENV_FILE" 2>/dev/null
        set +a
    fi
    # Support both CLAIM_MODE and MODE for compatibility (unify to CLAIM_MODE)
    local raw_mode="${CLAIM_MODE:-$MODE}"
    raw_mode="${raw_mode:-HEADLESS}"
    # Strip leading/trailing quotes
    export CLAIM_MODE=$(echo "$raw_mode" | sed 's/^["]//;s/["]$//;s/^['\'']//;s/['\'']$//')
}

stop_forbidden_tools() {
    local tools=("$@")
    if ! command -v pgrep >/dev/null 2>&1; then
        return
    fi
    for tool in "${tools[@]}"; do
        if pgrep -f "$tool" >/dev/null 2>&1; then
            echo -e "${YELLOW}[WARN]${NC} Forbidden display tool detected: $tool. Stopping..."
            pkill -9 -f "$tool" 2>/dev/null || true
        fi
    done
}

enforce_display_mode() {
    load_env
    
    if [ "$CLAIM_MODE" = "HEADLESS" ] || [ "$CLAIM_MODE" = "headless" ]; then
        # Enforcing strict HEADLESS mode...
        
        # 1. Stop forbidden tools
        stop_forbidden_tools "${FORBIDDEN_TOOLS[@]}"
        
        # 2. Specifically stop termux-x11 (to block all visual output)
        if pgrep -f "termux-x11" >/dev/null 2>&1; then
             echo -e "${YELLOW}[WARN]${NC} Termux:X11 detected in HEADLESS mode. Stopping output..."
             pkill -9 -f "termux-x11" 2>/dev/null || true
        fi
        
        # 3. Ensure Xvfb is running on :99
        if ! pgrep -x "Xvfb" >/dev/null 2>&1; then
            echo -e "${BLUE}[INFO]${NC} Starting Xvfb on :99..."
            nohup Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
            sleep 2
        fi
        
        export DISPLAY=:99
        
    elif [ "$CLAIM_MODE" = "DEVELOPMENT" ] || [ "$CLAIM_MODE" = "dev" ]; then
        # Enforcing DEVELOPMENT mode (Termux:X11 + XRDP allowed)...
        
        # 1. Stop forbidden tools EXCEPT xrdp
        local dev_forbidden=()
        for tool in "${FORBIDDEN_TOOLS[@]}"; do
            [ "$tool" != "xrdp" ] && dev_forbidden+=("$tool")
        done
        stop_forbidden_tools "${dev_forbidden[@]}"
        
        # 2. Xvfb can still run in background on :99 if needed, 
        # but primary display is :0 (Termux:X11)
        if ! pgrep -x "Xvfb" >/dev/null 2>&1; then
            nohup Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
        fi

        # 3. Ensure xrdp is running if installed
        if command -v xrdp >/dev/null 2>&1 && ! pgrep -x "xrdp" >/dev/null 2>&1; then
            echo -e "${BLUE}[INFO]${NC} Starting XRDP..."
            service xrdp start 2>/dev/null || /etc/init.d/xrdp start 2>/dev/null || true
        fi
        
        # Primary display for development
        export DISPLAY=:0
    else
        # Default to HEADLESS if unknown
        export CLAIM_MODE="HEADLESS"
        enforce_display_mode
    fi
}
