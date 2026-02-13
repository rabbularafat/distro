#!/bin/bash
# unix-xfce/scripts/01-system.sh
source "$(dirname "$0")/utils.sh"

log_info "Step 1: Updating system repositories..."
apt update && apt upgrade -y

log_info "Installing core dependencies..."
apt install -y wget curl gnupg2 software-properties-common build-essential dbus-x11

log_success "System update complete."
