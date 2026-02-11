#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_info "Step 1: Updating system packages..."
sudo apt update && sudo apt upgrade -y

log_info "Installing basic dependencies..."
sudo apt install -y wget curl gnupg2 software-properties-common

log_success "System update complete."
