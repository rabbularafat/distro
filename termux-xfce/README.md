# 📱 Termux XFCE4 + Debian Desktop

A premium, high-performance XFCE4 desktop environment running inside a Debian Proot-Distro on Termux. This setup allows you to run a full Linux desktop on your Android device without root.

---

## 🚀 Quick Start (Automated)

Run this single command in your Termux terminal to automate the entire installation:

```bash
pkg install curl -y && curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/termux-xfce/setup.sh | bash
```

---

## 🛠️ Manual Installation (Step-by-Step)

If you prefer to set up your environment manually, follow these detailed steps:

### 1. Host Environment (Termux)
Update the core system and install required tools:
```bash
pkg update -y && pkg upgrade -y
pkg install proot-distro pulseaudio wget curl -y
```

### 2. Guest OS Setup (Debian)
Install and enter the Debian environment:
```bash
proot-distro install debian
proot-distro login debian
```

Inside Debian, update and install system utilities:
```bash
apt update && apt upgrade -y
apt install sudo nano passwd adduser -y
```

### 3. User & Permissions
Create a dedicated user for your desktop:
```bash
adduser remote
usermod -aG sudo remote
```

Configure `sudo` access (automated way):
```bash
echo "remote ALL=(ALL:ALL) ALL" > /etc/sudoers.d/remote
chmod 440 /etc/sudoers.d/remote
exit
```

### 4. Desktop Environment (XFCE4)
Login as your new user and install the GUI:
```bash
proot-distro login debian --user remote

sudo apt update
sudo apt install xfce4 xfce4-goodies dbus-x11 tigervnc-standalone-server -y
```

### 5. VNC Server Configuration
Set up the VNC startup script:
```bash
# Set your VNC password
vncpasswd

# Create required directories (prevents TigerVNC migration error)
mkdir -p ~/.vnc
mkdir -p ~/.config/tigervnc

# Create and edit startup script
nano ~/.vnc/xstartup
```

Add the following content to `xstartup`:
```bash
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
```
*Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).*

Make it executable:
```bash
chmod +x ~/.vnc/xstartup
```

### 6. Web Browser Setup (Chromium)
Install Chromium and system fonts to avoid the **"Failed to execute default web browser"** error:
```bash
sudo apt install chromium fonts-noto-core fonts-noto-color-emoji -y
```

Chromium requires `--no-sandbox` in proot. Add this flag globally so it works from every shortcut and link:
```bash
sudo mkdir -p /etc/chromium.d
echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox"' | sudo tee /etc/chromium.d/proot-flags
```

Set Chromium as the default browser for XFCE:
```bash
mkdir -p ~/.config/xfce4
echo "WebBrowser=chromium" > ~/.config/xfce4/helpers.rc
```

---

## 🏁 Starting the Desktop

### 1. Start the VNC Server
Run this command from inside the Debian environment:
```bash
vncserver -localhost -geometry 1280x720
```

### 2. Connect via VNC Viewer
- Download **VNC Viewer** from the Play Store.
- Create a new connection to: `localhost:5901` (or `localhost:1`).
- Enter the password you created during `vncpasswd`.

---

## 🛑 Management Commands

| Action | Command |
| :--- | :--- |
| **Login** | `proot-distro login debian --user remote` |
| **Start VNC** | `vncserver -localhost -geometry 1280x720` |
| **Stop VNC** | `vncserver -kill :1` |
| **Exit Debian** | `exit` |

---

## 🐛 Troubleshooting

### "Failed to execute default web browser — Input/output error"

This error appears when **no web browser** is installed inside the Debian proot environment, or when the XFCE preferred browser is not configured.

**Fix (if already installed without a browser):**

1. Login to Debian:
   ```bash
   proot-distro login debian --user remote
   ```

2. Install Chromium:
   ```bash
   sudo apt install chromium fonts-noto-core fonts-noto-color-emoji -y
   ```

3. Enable `--no-sandbox` globally (required for proot):
   ```bash
   sudo mkdir -p /etc/chromium.d
   echo 'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox"' | sudo tee /etc/chromium.d/proot-flags
   ```

4. Set Chromium as the default browser:
   ```bash
   mkdir -p ~/.config/xfce4
   echo "WebBrowser=chromium" > ~/.config/xfce4/helpers.rc
   sudo update-alternatives --set x-www-browser /usr/bin/chromium
   ```

5. Restart your VNC session:
   ```bash
   vncserver -kill :1
   vncserver -localhost -geometry 1280x720
   ```

---

## 💡 Performance Tips
- Use **PulseAudio** for sound support.
- Adjust `-geometry` to match your phone's screen resolution for better clarity.
- For better performance, disable desktop animations in XFCE settings.

---
*Created with ❤️ for the Distro Project.*

