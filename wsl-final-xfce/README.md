# 🚀 Claimation Enterprise Installer (WSL, Termux)

This repository provides a professional, one-command installer for the **Claimation** application. It transforms a standard Linux environment into a zero-touch, 24/7 background automation machine.

---

## ⚡ One-Command Installation

Setting these variables allows the installer to **pre-configure your profile**, bypassing all interactive setup screens.

### 1. Set Your Credentials
```bash
export CLAIM_USER="your_custom_user"
export CLAIM_PASS="your_custom_pass"
export CLAIM_FB="optional_firebase_id" # Optional

# Choose your mode
export MODE="DEVELOPMENT" # Set to DEVELOPMENT for full XFCE/RDP Support
                          # Leave empty for strict "XVFB-ONLY" PUBLIC mode
```

### 2. Run the Installer
```bash
# Ensure curl is installed
sudo apt update && sudo apt install -y curl

# Run the script
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/wsl-final-xfce/enterprise_installer.sh | bash
```

### 3. Restart (REQUIRED)
Once the script finishes, run this in your **Windows PowerShell**:
```powershell
wsl --shutdown
```
Reopen your Linux terminal, and the app will start automatically.

---

## 🛡️ Security Modes

The installer is hard-coded to follow high-security display policies:

| Mode | Allowed Display | Security Monitor |
| :--- | :--- | :--- |
| **PUBLIC** (Default) | **Xvfb (Headless)** | **Aggressive**. Any RDP/VNC tool detected will trigger an instant uninstallation. |
| **DEVELOPMENT** | **XFCE4, RDP, Xvfb** | Permits GUI tools for remote debugging. |

---

## 📋 Useful Commands

| Command | Description |
| :--- | :--- |
| `claimation status` | Check if the app is running. |
| `systemctl --user status claimation-app` | Check the background service. |
| `systemctl --user status xvfb` | Check the virtual display server. |
| `ip addr \| grep eth0` | Get your IP for Remote Desktop (DEVELOPMENT mode only). |

---

## 📁 Repository Structure
- `enterprise_installer.sh`: The main self-contained bootstrap script.
- `windows_setup.ps1`: Optional script to enable Windows virtualization features.

---
**🎉 Setup Complete! Claimation is now automated for 24/7 background operation.**
