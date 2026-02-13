# 🚀 WSL2 + Debian + XFCE4 + XRDP: The Ultimate Guide

This single guide contains everything you need to set up a full Linux Desktop Environment (XFCE4) on Windows 10 or 11 using WSL2 and Remote Desktop (XRDP).

---

## 🛠 SECTION 1: Windows Preparation (PowerShell Administrator)

Before installing Linux, you must enable the necessary Windows features.

1.  **Open PowerShell as Administrator.**
2.  **Enable WSL & Virtual Machine Platform:**
    ```powershell
    # Enable WSL
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

    # Enable Virtual Machine Platform
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    ```
3.  **🚨 RESTART YOUR PC NOW.** This step is required for the features to activate.

---

## 📦 SECTION 2: Install WSL & Linux

1.  **Check Version Support:** Run `winver`. You need Windows 10 (Build 19041+) or Windows 11.
2.  **Set WSL 2 as Default:**
    ```powershell
    wsl --install
    wsl --set-default-version 2
    ```
3.  **Download Debian:**
    - Open the **Microsoft Store**.
    - Search for **Debian**.
    - Click **Get** and then **Open**.
4.  **Initial Setup:** Follow the prompts in the terminal to create your **Username** and **Password**.

---

## 🔎 SECTION 3: Troubleshooting Virtualization

If you get an error like *"Virtualization not enabled"*:
1.  **Restart PC** and enter **BIOS/UEFI** (usually `F2`, `F10`, `DEL`, or `Esc`).
2.  **Enable Virtualization:**
    - **Intel:** Enable **Intel VT-x** / **Intel Virtualization Technology**.
    - **AMD:** Enable **SVM Mode** / **Secure Virtual Machine**.
3.  Save and Exit (`F10`).
4.  Verify in PowerShell: `wsl --status`.

---

## 🐧 SECTION 4: Linux Desktop Configuration (Inside Debian)

Launch your Debian terminal and run these steps in order.

### 1. Update System & Install Essentials
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget gnupg2 software-properties-common dbus-x11
```

### 2. Enable systemd (Required for XRDP)
```bash
sudo nano /etc/wsl.conf
```
Add the following lines to the file:
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
Then reopen **Debian** from the Start menu.

### 4. Create a Remote User (Recommended)
```bash
sudo adduser remote
sudo usermod -aG sudo,adm remote
```

### 5. Install XFCE4 Desktop
```bash
sudo apt update
sudo apt install xfce4 xfce4-goodies -y
sudo systemctl set-default graphical.target
```

---

## 🖥 SECTION 5: Install & Configure XRDP

```bash
# Install XRDP
sudo apt install xrdp -y

# Configure XRDP to use XFCE
echo xfce4-session > ~/.xsession
chmod +x ~/.xsession

# Fix X11 Permissions
sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config

# Enable and Start XRDP Service
sudo systemctl enable xrdp
sudo systemctl start xrdp
```

Check if it's running: `sudo systemctl status xrdp` (Should be green/active).

---

## 🔌 SECTION 6: Connect via Remote Desktop

1.  **Find your IP:** In Debian, run:
    ```bash
    ip addr | grep eth0
    ```
    *Look for the `inet` address (e.g., 172.25.10.5).*
2.  **Open RDP:** Press `Win + R`, type `mstsc`, and hit Enter.
3.  **Login:**
    - **Computer:** Paste your WSL IP.
    - **Username:** `remote` (or your own).
    - **Password:** The password you created.

---

## ⚙️ SECTION 7: Global Improvements (Optional)

### Disable WSLg
If you want to disable the default Windows Linux GUI support to prevent conflicts:
1. Create `C:\Users\YOUR_USERNAME\.wslconfig`.
2. Add:
   ```ini
   [wsl2]
   guiApplications=false
   ```
3. Run `wsl --shutdown` in PowerShell.

### Dependency Fixes
If you get errors during installation, ensure all dependencies are met:
```bash
sudo apt update
sudo apt install -y curl wget dependencies-met-check
```

---
**🎉 Everything is now set up! Your WSL Debian system is ready for use.**
