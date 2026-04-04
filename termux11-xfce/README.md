# Termux11-XFCE: The Modern Way to Run Debian XFCE in Termux

This repository provides a modernized replacement for the buggy VNC-based Termux-XFCE installers. By utilizing the official **Termux:X11** display server, it offers:
- 🚀 **Faster Performance**: Direct X11 rendering instead of network-based VNC.
- 🛠️ **Higher Stability**: No more `shm-helper` errors or port crashes.
- 🔊 **Better Audio**: Integrated PulseAudio support.
- ✨ **Simplicity**: No VNC password setup or port configuration.

---

## ⚡ ONE-COMMAND INSTALLATION

Copy and paste the command below into your **Termux** app to begin the installation:

```bash
pkg update -y && pkg install wget -y && wget https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-xfce/install.sh && chmod +x install.sh && bash install.sh
```

---

## 🏗️ HOW TO START THE DESKTOP

1. **Install the App**: Download and install the **Termux:X11 Android APK** from [GitHub Releases](https://github.com/termux/termux-x11/releases).
2. **Open the App**: Launch the **Termux:X11** app on your phone. You will see a black screen waiting for a connection.
3. **Launch in Termux**: Go back to the **Termux** app and type:
   ```bash
   start-xfce
   ```
4. **Switch Back**: Return to the **Termux:X11** app. Your Debian XFCE desktop will appear instantly!

---

## 🖥️ WHY THIS IS BETTER THAN VNC

| Feature | Old VNC Method | Termux11-XFCE (Modern) |
| :--- | :--- | :--- |
| **Connection Method** | Local Network (Port 5901) | Direct Display Server |
| **Speed** | 🐢 Latency / Lag | ⚡ Smooth & Fast |
| **Stability** | ❌ Prone to "Port not reached" | ✅ Rock Solid |
| **Setup** | 🔑 Needs VNC Password | ✨ Zero Config |

---

## 🛠️ TROUBLESHOOTING

### 1. Black Screen / No Desktop?
Ensure you have the **Termux:X11 app open** on your phone *before* running the `start-xfce` command.

### 2. No Audio?
The installer automatically configures PulseAudio. If sound is missing, make sure you have allowed audio permissions for the Termux app in your device settings.

### 3. Chromium Crashing?
Chromium in specialized environments like proot requires the `--no-sandbox` flag. This setup automatically applies this flag, but if you launch it via command line, remember to use it.

---

## 📝 CREDITS
Built for the **Termux Community** as a more reliable alternative to outdated VNC guides.
