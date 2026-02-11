# WSL Debian XFCE4 + XRDP Installer (Pro Version)

A modular, enterprise-grade installer for setting up a full XFCE4 desktop environment on WSL2 Debian with XRDP support.

## 🚀 One-Line Installation

Run this command in your WSL Debian terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/install.sh | bash
```

## 📦 What's Included

- **System Update**: Automated `apt` update and upgrade.
- **XFCE4 Desktop**: Full desktop environment installation.
- **XRDP Server**: Remote Desktop protocol setup for Windows connection.
- **WSL Optimization**: Automatic `systemd` enablement in `wsl.conf`.
- **Session Control**: Automatic `.xsession` configuration.

## 🛠 Project Structure

- `setup.sh`: Main entry point.
- `scripts/utils.sh`: Color logging system.
- `scripts/01-system.sh`: Package management.
- `scripts/02-xfce.sh`: Desktop environment.
- `scripts/03-xrdp.sh`: Remote access.
- `scripts/04-wsl.sh`: WSL tweaks.

## 🏁 Post-Installation

After the script finishes:
1. Run `wsl --shutdown` in Windows PowerShell.
2. Re-open Debian.
3. Check IP with `ip addr`.
4. Connect via Windows Remote Desktop (`mstsc`).
