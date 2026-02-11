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

echo -e "${CYAN}========================================================${NC}"
echo -e "${CYAN}   🚀 WSL DEBIAN XFCE4 + XRDP ENTERPRISE INSTALLER   ${NC}"
echo -e "${CYAN}========================================================${NC}"
echo ""

# Execute scripts in sequence
bash "$SCRIPTS_DIR/01-system.sh"
bash "$SCRIPTS_DIR/02-xfce.sh"
bash "$SCRIPTS_DIR/03-xrdp.sh"
bash "$SCRIPTS_DIR/04-wsl.sh"

echo ""
echo -e "${CYAN}========================================================${NC}"
echo -e "${GREEN}✅ ALL STEPS COMPLETED SUCCESSFULLY!${NC}"
echo -e "${CYAN}========================================================${NC}"
echo ""
log_warn "🚨 CRITICAL NEXT STEPS 🚨"
echo ""
echo -e "1. ${YELLOW}Restart WSL:${NC} Run this in Windows PowerShell:"
echo -e "   ${MAGENTA}wsl --shutdown${NC}"
echo ""
echo -e "2. ${YELLOW}Reconnect to Debian:${NC} Open your Debian terminal again."
echo ""
echo -e "3. ${YELLOW}Find your IP:${NC} Run this inside Debian:"
echo -e "   ${MAGENTA}ip addr | grep eth0${NC}"
echo ""
echo -e "4. ${YELLOW}Launch RDP:${NC} Open 'Remote Desktop Connection' in Windows (mstsc)."
echo -e "   - ${CYAN}Computer:${NC} [Your WSL IP]"
echo -e "   - ${CYAN}Username:${NC} $(whoami)"
echo ""
echo -e "${CYAN}Enjoy your Linux Desktop experience!${NC}"
echo ""
