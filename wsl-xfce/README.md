# 🚀 WSL2 XFCE4 Desktop + Claimation Guide (Debian, Ubuntu, Kali)

This guide sets up a full Linux Desktop Environment (XFCE4) on Windows 10/11 using WSL2 with **automated Claimation deployment** running 24/7 in the background.

---

## 🛠 Step 1: Windows Preparation

Before installing Linux, enable the necessary Windows features.

### Option A: Using the Windows GUI (Recommended)
1.  Press `Win + R`, type `optionalfeatures`, and hit **Enter**.
2.  Ensure the following are **checked**:
    -   [x] **Virtual Machine Platform**
    -   [x] **Windows Subsystem for Linux**
    -   [x] **SMB Direct** (Optimizes file transfer)
    -   [x] **Work Folders Client**
3.  Click **OK** and wait for the process to finish.
4.  **🚨 RESTART YOUR PC NOW.**

### Option B: Using PowerShell (Administrator)
```powershell
# Enable WSL & Virtual Machine Platform
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Enable SMB Direct & Work Folders
dism.exe /online /enable-feature /featurename:SMB-Direct /all /norestart
dism.exe /online /enable-feature /featurename:WorkFolders-Client /all /norestart
```
**🚨 RESTART YOUR PC NOW.**

---

## 📦 Step 2: Install Your Distribution

1.  **Check Version Support:** Run `winver`. You need Windows 10 (Build 19041+) or Windows 11.
2.  **Set WSL 2 as Default:** (Run in PowerShell)
    ```powershell
    wsl --install
    wsl --set-default-version 2
    ```
3.  **Download from Microsoft Store:**
    - **Debian**: [Get Debian](https://apps.microsoft.com/store/detail/debian/9MSVKQC78PK6)
    - **Ubuntu**: [Get Ubuntu](https://apps.microsoft.com/store/detail/ubuntu/9PDXG59B9PCL)
    - **Kali Linux**: [Get Kali Linux](https://apps.microsoft.com/store/detail/kali-linux/9PKR34T7PVMX)
4.  **Initial Setup:** Open your chosen distro and create your **Username** and **Password**.

---

## 🔎 Step 3: Troubleshooting Virtualization

If you get an error like *"Virtualization not enabled"*:
1.  **Restart PC** and enter **BIOS/UEFI** (usually `F2`, `F10`, `DEL`, or `Esc`).
2.  **Enable Virtualization:**
    - **Intel:** Enable **Intel VT-x** / **Intel Virtualization Technology**.
    - **AMD:** Enable **SVM Mode** / **Secure Virtual Machine**.
3.  **Verify** in PowerShell: `wsl --status`.

---

## ⚡ Step 4: One-Command Installation (Recommended)

> **⚠️ CRITICAL:** Run this inside your **Linux Terminal** (WSL), not PowerShell.

### Set Your Credentials & Run
Setting these variables allows the installer to **pre-configure your profile**, bypassing all interactive setup screens for true 24/7 "Zero-Touch" operation.

```bash
# 1. Set your dynamic credentials
export CLAIM_USER="your_custom_user"
export CLAIM_PASS="your_custom_pass"
export CLAIM_FB="optional_firebase_id"

# 2. Ensure curl is installed
sudo apt update && sudo apt install -y curl

# 3. Run the enterprise installer
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/wsl-xfce/enterprise_installer.sh | bash
```

### After Installation

```powershell
# Run this in Windows PowerShell (REQUIRED — one time only)
wsl --shutdown
```

Then reopen your Debian terminal. **Everything starts automatically:**

| Service | Status |
|:---|:---|
| ✅ Xvfb (Virtual Display) | Auto-starts on boot |
| ✅ Claimation | Runs 24/7 in background |
| ✅ Auto-Updater | Checks for updates automatically |
| ✅ XRDP | Available for optional remote desktop |

> **No Remote Desktop Connection needed!** Claimation runs headlessly via Xvfb (virtual framebuffer). All GUI automation (pyautogui, Chrome, pyperclip) works on Xvfb.

---

## 📋 Useful Commands

```bash
# Check Claimation status
claimation status

# Check services
systemctl --user status claimation-app
systemctl --user status xvfb

# Launch Chrome (auto DISPLAY — just works!)
google-chrome

# Optional: Get your WSL IP for Remote Desktop
ip addr | grep eth0
```

---

## 🐧 Manual Configuration (Step-by-Step)

If you prefer manual setup, launch your Linux terminal and follow these steps.

### 1. Update System & Install Essentials
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget gnupg2 dbus-x11
```

### 2. Enable systemd (Required for XRDP)
```bash
sudo nano /etc/wsl.conf
```
Add the following lines:
```ini
[boot]
systemd=true
```
Save (`Ctrl+O`, `Enter`) and Exit (`Ctrl+X`).

### 3. Restart WSL
Go back to **Windows PowerShell** and run:
```powershell
wsl --shutdown
```
Then reopen your Linux distro.

### 4. Install XFCE4 Desktop & XRDP
```bash
sudo apt update
sudo apt install xfce4 xfce4-goodies xrdp xvfb xclip x11-xserver-utils -y

# Configure XRDP to use XFCE
echo xfce4-session > ~/.xsession
chmod +x ~/.xsession

# Fix X11 Permissions
sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config

# Enable and Start XRDP Service
sudo systemctl set-default graphical.target
sudo systemctl enable xrdp
sudo systemctl start xrdp
```

### 5. Install Claimation
```bash
wget https://github.com/rabbularafat/wsmation/releases/download/v1.5.3/claimation_1.5.3-1_all.deb
sudo dpkg -i claimation_1.5.3-1_all.deb
sudo apt-get install -f -y
```

---

## 🔌 Optional: Connect via Remote Desktop

1.  **Find your IP:** In your Linux terminal, run:
    ```bash
    hostname -I
    ```
2.  **Open RDP:** Press `Win + R`, type `mstsc`, and hit Enter.
3.  **Login:**
    - **Computer:** Paste your WSL IP.
    - **Username:** Your Linux username.
    - **Password:** Your Linux password.

---

## 🧬 Note for Kali Linux Users (Win-KeX)
Kali Linux users can also use **Win-KeX** for a more integrated experience:
```bash
sudo apt update
sudo apt install kali-win-kex -y
kex --esm --ip --sound
```

---
**🎉 Setup Complete! Claimation is running 24/7 in the background.**
