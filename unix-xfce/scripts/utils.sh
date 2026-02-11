#!/bin/bash
# unix-xfce/scripts/utils.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo."
        exit 1
    fi
}

get_distro() {
    if grep -qi "ubuntu" /etc/os-release; then
        echo "ubuntu"
    elif grep -qi "debian" /etc/os-release; then
        echo "debian"
    else
        echo "unknown"
    fi
}
