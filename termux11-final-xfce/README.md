# TERMUX11 FINAL XFCE4: Claimation Enterprise v3.0 (Android)

Run a full Debian XFCE4 Desktop or an Automated Worker on your Android device with **automated Claimation deployment** using Termux:X11.

- 🚀 **Fast**: Direct X11 rendering (no VNC lag)
- 🛠️ **Stable**: No more `shm-helper` errors or port crashes
- 🛡️ **Secure**: Integrated "Poison Pill" security mechanism (in PUBLIC mode)
- ✨ **Zero-Touch**: Automatic setup of Cloud IDs and credentials
- 🔄 **24/7 Ready**: Built-in **Watchdog** service restarts Claimation if it crashes
- 🔋 **Persistence**: Includes `termux-wake-lock` to prevent Android from sleeping the process

---

## ⚡ ONE-COMMAND INSTALLATION (Enterprise v3.0)

Choose your mode and install with ease:

```bash
# 1. Set your credentials
export CLAIM_USER="your_custom_user"
export CLAIM_PASS="your_custom_pass"
export CLAIM_FB="optional_firebase_id"

# 2. Select your Mode (DEVELOPMENT for Desktop / PUBLIC for Automation)
export MODE="DEVELOPMENT" 
export DEVICE="TERMUX"

# 3. Install everything
pkg update -y && pkg install curl -y && \
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/termux11-final-xfce/install.sh | bash
```

---

## 🏗️ OPERATIONAL MODES

| Mode | Desktop (X11) | PyAutoGUI | Security | Best For |
| :--- | :--- | :--- | :--- | :--- |
| **`DEVELOPMENT`** | ✅ Enabled | ✅ Visible | Permissive | Debugging & Setup |
| **`PUBLIC`** | ❌ Disabled | ✅ Enabled | **Poison Pill** | 24/7 Production |

---

## 🖥️ HOW TO START THE DESKTOP (DEVELOPMENT mode only)

1. **Install the App**: Download [Termux:X11 APK](https://github.com/termux/termux-x11/releases)
2. **Open the App**: Launch **Termux:X11** — you'll see a black screen waiting
3. **Launch in Termux**: Go back to Termux and type:
   ```bash
   start-xfce
   ```
4. **Switch Back**: Return to Termux:X11 — your desktop appears!

---

## ⚡ CRITICAL: ACTIVATION after install
The persistence layer requires a **single restart** of the Termux app to activate:

1. **CLOSE Termux**: Swipe the app away from your Recent Apps.
2. **REOPEN Termux**: Open the app again.
3. **WAIT 30s**: Give the background watchdog a moment to initialize.
4. **VERIFY**: Type `proot-distro login debian -- claimation status`. It should show **🟢 RUNNING**.

---

## 🔋 24/7 Background Operation
To ensure Claimation runs without being killed by Android:
1.  **Install Termux:Boot**: `pkg install termux-boot` (then open Termux:Boot app once)
2.  **Disable Battery Optimization**: Go to *Settings > Apps > Termux > Battery* and set to **"Unrestricted"**
3.  **Acquire Wakelock**: Pull down the Termux notification and tap **"Acquire Wakelock"**

---

## 📋 Useful Commands (Inside Termux)

```bash
# Check Claimation Status (Quick)
proot-distro login debian -- claimation status

# Start Desktop (Only if in DEVELOPMENT mode)
start-xfce

# Force Update Claimation
proot-distro login debian -- claimation update --force
```

---

## 🛠️ TROUBLESHOOTING

### What is the "Poison Pill"?
In **`PUBLIC`** mode, if you manually install XFCE or X11 tools, the app will detect it as a security breach and **purge itself** to protect data. Always use **`DEVELOPMENT`** mode if you want a desktop interface.

### No Desktop?
Ensure **Termux:X11 app** is open *before* running `start-xfce`. If you are in `PUBLIC` mode, `start-xfce` will not work.

---

## 📝 CREDITS
Built for the **Termux Community** as a professional background automation environment.
