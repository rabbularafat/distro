# Termux XFCE4 + Debian Desktop

Automated setup for a full desktop environment on Android.

## 🚀 Installation

Run this in Termux:
```bash
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/termux-xfce/setup.sh | bash
```

## 🏁 Post-Installation

1. Enter the guest OS:
   ```bash
   proot-distro login debian --user remote
   ```
2. Start the VNC server:
   ```bash
   vncserver -localhost -geometry 1280x720
   ```
3. Connect using **VNC Viewer** (Android) to:
   - **Address:** `localhost:1` or `localhost:5901`
   - **Password:** The password you set during `vncserver` setup.

## 🛑 Stop VNC
```bash
vncserver -kill :1
```
