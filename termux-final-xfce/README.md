# 🚀 Claimation Enterprise Installer — Termux (Android)

Run a full Debian XFCE4 Desktop or an Automated 24/7 Worker on your Android device with **automated Claimation deployment** using Termux:X11.

- 🚀 **Fast**: Direct X11 rendering (no VNC lag)
- 🛠️ **Stable**: No more `shm-helper` errors or port crashes
- 🛡️ **Secure**: Integrated "Poison Pill" security mechanism (in `PUBLIC` mode)
- ✨ **Zero-Touch**: Automatic setup of Cloud IDs and credentials
- 🔄 **24/7 Ready**: **Host-side watchdog** runs permanently on Termux (not inside proot)
- 🔋 **Persistent**: `termux-wake-lock` + `.bashrc` auto-start on every Termux session
- 🔍 **Diagnosable**: Full debug logging for architecture, dependencies, and runtime

---

## ⚡ ONE-COMMAND INSTALLATION (Enterprise v4.0)

```bash
# 1. Set your credentials
export CLAIM_USER="your_custom_user"
export CLAIM_PASS="your_custom_pass"
export CLAIM_FB="optional_firebase_id"

# 2. Select your Mode
export MODE="DEVELOPMENT"   # DEVELOPMENT for Desktop / PUBLIC for Automation
export DEVICE="TERMUX"

# 3. Install everything
pkg update -y && pkg install curl -y && \
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/termux-final-xfce/install.sh | bash
```

---

## 🏗️ HOW IT WORKS (vs WSL)

| Feature | WSL | Termux |
| :--- | :--- | :--- |
| **Service manager** | systemd | Host-side watchdog script |
| **Persistence** | systemd enable + linger | `.bashrc` auto-start hook |
| **Display** | Xvfb via service | Xvfb started by watchdog |
| **Process location** | Inside Linux | Watchdog on HOST, claimation inside proot |

**Key architectural fix**: The persistent watchdog loop runs on the **Termux HOST side**, not inside proot-distro. This means it survives proot session exits and manages claimation via `proot-distro login debian -- ...` calls.

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

## 🔋 24/7 Background Operation

To ensure Claimation runs without Android killing it:

1. **Disable Battery Optimization**: *Settings > Apps > Termux > Battery* → **"Unrestricted"**
2. **Acquire Wakelock**: Pull down the Termux notification and tap **"Acquire Wakelock"**
3. **Optional - Termux:Boot**: `pkg install termux-boot` (then open Termux:Boot app once)

The installer automatically acquires `termux-wake-lock` on every startup.

---

## 📋 Useful Commands (Inside Termux)

```bash
# Check Claimation Status
claimation-status

# Monitor Live Bot Output
claimation-logs

# View Watchdog Debug Log
claimation-debug

# Start Desktop (DEVELOPMENT mode only)
start-xfce

# Force Update Claimation
proot-distro login debian -- claimation update --force
```

---

## 🔍 DEBUG & DIAGNOSTICS

All operations are logged to files for troubleshooting:

| Log | Location | Description |
| :--- | :--- | :--- |
| Install Log | `~/.claimation/install-debug.log` | Full installation output |
| Watchdog Log | `~/.claimation/logs/watchdog.log` | Health checks, restarts, errors |
| Bot Log | *(inside guest)* `/root/.claimation/logs/claimation.log` | Claimation application output |

The installer performs these checks automatically:
- ✅ Architecture compatibility (`uname -m` vs `.deb`)
- ✅ Binary existence (`which claimation`)
- ✅ Library dependencies (`ldd`)
- ✅ Quick execution test (`claimation --help`)
- ✅ Runtime start verification (30s timeout)

**If anything fails, the error is printed + logged — never silent.**

---

## 🛠️ TROUBLESHOOTING

### Claimation not starting?
```bash
# Check the watchdog log first:
claimation-debug

# Check if watchdog itself is running:
pgrep -f claimation-watchdog

# Manually restart the watchdog:
pkill -f claimation-watchdog
bash ~/.claimation/claimation-watchdog.sh &
```

### What is the "Poison Pill"?
In **`PUBLIC`** mode, if you manually install XFCE or X11 tools, the app will detect it as a security breach and **purge itself** to protect data. Always use **`DEVELOPMENT`** mode when you want a desktop interface.

---

## 📝 CREDITS
Built for the **Termux Community** as a professional background automation environment.
Adapted from the WSL Enterprise Installer with Termux-specific persistence architecture.
