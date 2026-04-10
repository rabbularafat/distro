#!/bin/bash

# Define the base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

# Source utilities if available locally
if [ -f "$SCRIPTS_DIR/utils.sh" ]; then
    source "$SCRIPTS_DIR/utils.sh"
else
    echo "Error: utils.sh not found in $SCRIPTS_DIR"
    exit 1
fi

check_root

echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│   WSL DEBIAN XFCE4 + CLAIMATION ENTERPRISE INSTALLER   │${NC}"
echo -e "${CYAN}│                       v3.0                              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
echo ""

# Execute scripts in sequence
bash "$SCRIPTS_DIR/01-system.sh"
bash "$SCRIPTS_DIR/02-xfce.sh"
bash "$SCRIPTS_DIR/03-xrdp.sh"
bash "$SCRIPTS_DIR/04-wsl.sh"
bash "$SCRIPTS_DIR/05-claimation.sh"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✅ ALL STEPS COMPLETED SUCCESSFULLY!${NC}                    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}🚨 REQUIRED: Restart WSL once to activate systemd${NC}"
echo -e "   Run this in ${WHITE}Windows PowerShell${NC}:"
echo -e "   ${MAGENTA}wsl --shutdown${NC}"
echo -e "   Then reopen your Debian terminal."

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}What happens after restart:${NC}                             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Xvfb starts automatically (virtual display :99)       ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Claimation starts automatically (24/7 background)     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} Auto-updater daemon runs as system service            ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${GREEN}✓${NC} No Remote Desktop Connection needed!                  ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Useful commands:${NC}                                        ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    ${MAGENTA}claimation status${NC}       — Check if running              ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    ${MAGENTA}systemctl --user status claimation-app${NC}                  ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    ${MAGENTA}systemctl --user status xvfb${NC}                            ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    ${MAGENTA}google-chrome${NC}           — Just works! (auto DISPLAY)    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${WHITE}Optional RDP access:${NC}                                    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    ${BLUE}ip addr | grep eth0${NC}  — Get your WSL IP                 ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    Connect via mstsc with your Linux credentials         ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"

if [ -n "$CLAIM_USER" ]; then
    echo ""
    echo -e "  ${GREEN}✅ Claimation Profile:${NC} $CLAIM_USER (auto-configured)"
fi
echo ""
