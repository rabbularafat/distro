# Termux11-XFCE: Modern Debian Desktop + Claimation for Android

Run a full Debian XFCE4 Desktop on your Android device with **automated Claimation deployment** using Termux:X11.

- 🚀 **Fast**: Direct X11 rendering (no VNC lag)
- 🛠️ **Stable**: No more `shm-helper` errors or port crashes
- 🔊 **Audio**: Integrated PulseAudio support
- ✨ **Simple**: No VNC password setup, no port configuration
- 🤖 **Automated**: Claimation auto-starts with the desktop
- 🔄 **24/7 Ready**: Built-in **Watchdog** service restarts Claimation if it crashes
- 🔋 **Persistence**: Includes `termux-wake-lock` to prevent Android from sleeping the process

---

## ⚡ ONE-COMMAND INSTALLATION

```bash
# 1. Set your credentials
export CLAIM_USER="your_custom_user"
export CLAIM_PASS="your_custom_pass"
export CLAIM_FB="optional_firebase_id"

# 2. Install everything
pkg update -y && pkg install curl -y && \
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-xfce/install.sh -o install.sh && \
chmod +x install.sh && bash install.sh
```

---

## 🏗️ HOW TO START THE DESKTOP

1. **Install the App**: Download [Termux:X11 APK](https://github.com/termux/termux-x11/releases)
2. **Open the App**: Launch **Termux:X11** — you'll see a black screen waiting
3. **Launch in Termux**: Go back to Termux and type:
   ```bash
   start-xfce
   ```
4. **Switch Back**: Return to Termux:X11 — your desktop appears!

> **Note**: Claimation runs 24/7 via a **3-layer persistence** system:
> 
> | Layer | Trigger | What it does |
> | :--- | :--- | :--- |
> | **Termux .bashrc** | Opening any Termux session | Auto-starts watchdog inside proot |
> | **Proot .bashrc** | `proot-distro login debian` | Auto-starts watchdog on login |
> | **Termux:Boot** | Phone reboot | Auto-starts watchdog + wake-lock |
> | **XFCE Autostart** | Starting desktop | Starts watchdog (legacy fallback) |
> 
> ### 🔋 24/7 Background Operation
> To ensure Claimation runs without being killed by Android:
> 1.  **Install Termux:Boot**: `pkg install termux-boot` (then open Termux:Boot app once)
> 2.  **Disable Battery Optimization**: Go to *Settings > Apps > Termux > Battery* and set to **"Unrestricted"**
> 3.  **Acquire Wakelock**: Pull down the Termux notification and tap **"Acquire Wakelock"**
> 4.  **Keep App Open**: Do not swipe Termux out of your recent apps list

---

## 🖥️ WHY THIS IS BETTER THAN VNC

| Feature | Old VNC Method | Termux11-XFCE (Modern) |
| :--- | :--- | :--- |
| **Connection** | Local Network (Port 5901) | Direct Display Server |
| **Speed** | 🐢 Latency / Lag | ⚡ Smooth & Fast |
| **Stability** | ❌ Prone to "Port not reached" | ✅ Rock Solid |
| **Setup** | 🔑 Needs VNC Password | ✨ Zero Config |
| **Claimation** | Manual install | ✅ Auto-installed + Auto-start |

---

## 📋 Useful Commands

```bash
# Start desktop
start-xfce

# Check Claimation (inside Debian)
proot-distro login debian -- claimation status

# Run Claimation manually (inside Debian)
proot-distro login debian -- claimation run
```

---

## 🛠️ TROUBLESHOOTING

### Black Screen / No Desktop?
Ensure **Termux:X11 app** is open *before* running `start-xfce`.

### No Audio?
PulseAudio is auto-configured. Check audio permissions for Termux in device settings.

### Chromium Crashing?
The `--no-sandbox` flag is automatically applied. If launching via terminal:
```bash
chromium --no-sandbox
```

---

## 📝 CREDITS
Built for the **Termux Community** as a reliable alternative to outdated VNC guides.
