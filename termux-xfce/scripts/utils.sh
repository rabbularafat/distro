#!/bin/bash

# Termux Side Utility Script
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[TERMUX]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

check_termux() {
    if [ -z "$TERMUX_VERSION" ]; then
        echo "This script is designed for Termux on Android."
        exit 1
    fi
}
