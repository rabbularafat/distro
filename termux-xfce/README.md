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

## 💡 Performance Tips
- Use **PulseAudio** for sound support.
- Adjust `-geometry` to match your phone's screen resolution for better clarity.
- For better performance, disable desktop animations in XFCE settings.

---
*Created with ❤️ for the Distro Project.*
