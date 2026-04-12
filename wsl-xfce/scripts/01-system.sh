#!/bin/bash
source "$(dirname "$0")/utils.sh"

log_info "Step 1: Preconfiguring packages to prevent interactive prompts..."
preconfigure_packages

log_info "Updating system packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

log_info "Installing basic dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gnupg2 software-properties-common

log_success "System update complete."
