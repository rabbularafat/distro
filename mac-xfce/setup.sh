#!/bin/bash
# mac-xfce/setup.sh

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/scripts/utils.sh"

check_mac
check_brew

clear
echo -e "${MAGENTA}========================================================${NC}"
echo -e "${MAGENTA}   🍏 MACOS XFCE4 DESKTOP INSTALLER (MULTIPASS)     ${NC}"
echo -e "${MAGENTA}========================================================${NC}"
echo ""

# 1. Install Multipass if missing
if ! command -v multipass &> /dev/null; then
    log_info "Multipass not found. Installing via Homebrew..."
    brew install multipass
else
    log_success "Multipass is installed."
fi

# 2. Launch or Start Instance
VM_NAME="mac-xfce-desktop"
if multipass list | grep -q "$VM_NAME"; then
    log_info "Instance '$VM_NAME' already exists. Starting it..."
    multipass start "$VM_NAME"
else
    log_info "Launching new Linux instance for XFCE (2 CPUs, 4GB RAM)..."
    multipass launch --name "$VM_NAME" --cpus 2 --mem 4G --disk 20G
fi

# 3. Use the remote unix-xfce setup inside the VM
log_info "Installing XFCE environment inside the instance..."
multipass exec "$VM_NAME" -- bash -c "curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/unix-xfce/setup.sh | sudo bash"

# 4. Success Summary
VM_IP=$(multipass info "$VM_NAME" --format csv | grep "$VM_NAME" | cut -d',' -f3)

echo ""
echo -e "${MAGENTA}========================================================${NC}"
echo -e "${GREEN}✅ MACOS XFCE SETUP COMPLETE!${NC}"
echo -e "${MAGENTA}========================================================${NC}"
echo ""
log_info "Your Linux Desktop is running inside Multipass."
echo -e "1. ${YELLOW}VM Name:${NC} $VM_NAME"
echo -e "2. ${YELLOW}VM IP Address:${NC} $VM_IP"
echo ""
echo -e "To connect from macOS:"
echo -e "- Use Microsoft Remote Desktop (from App Store)."
echo -e "- Connect to PC: ${CYAN}$VM_IP${NC}"
echo -e "- Log in with your VM credentials (default user is 'ubuntu')."
echo ""
echo -e "To open a terminal in the VM: ${MAGENTA}multipass shell $VM_NAME${NC}"
echo ""
