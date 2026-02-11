#!/bin/bash
# unix-xfce/setup.sh

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

source "$SCRIPTS_DIR/utils.sh"

# Check for root
check_root

clear
echo -e "${CYAN}========================================================${NC}"
echo -e "${CYAN}   🚀 NATIVE LINUX XFCE4 + XRDP INSTALLER (UNIX)     ${NC}"
echo -e "${CYAN}========================================================${NC}"
echo ""

# Execute sequence
bash "$SCRIPTS_DIR/01-system.sh"
bash "$SCRIPTS_DIR/02-xfce.sh"
bash "$SCRIPTS_DIR/03-xrdp.sh"

echo ""
echo -e "${CYAN}========================================================${NC}"
echo -e "${GREEN}✅ NATIVE INSTALLATION COMPLETE!${NC}"
echo -e "${CYAN}========================================================${NC}"
echo ""
log_info "Next Steps:"
echo -e "1. You can now log into XFCE locally if you have a monitor."
echo -e "2. For remote access, use Windows 'mstsc' to connect to this PC's IP."
echo -e "3. Current User: $(whoami)"
echo ""
