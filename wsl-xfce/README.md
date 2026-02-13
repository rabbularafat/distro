# 🚀 WSL2 XFCE4 Desktop Guide (Debian, Ubuntu, Kali)

This ultimate guide contains everything you need to set up a full Linux Desktop Environment (XFCE4) on Windows 10 or 11 using WSL2 and Remote Desktop (XRDP). This process works for **Debian**, **Ubuntu**, and **Kali Linux**.

---

## 🛠 Step 1: Windows Preparation

Before installing Linux, you must enable the necessary Windows features. You can do this using the GUI or PowerShell.

### Option A: Using the Windows GUI (Recommended)
1.  Press `Win + R`, type `optionalfeatures`, and hit **Enter**.
2.  In the "Turn Windows features on or off" window, ensure the following are **checked**:
    -   [x] **Virtual Machine Platform**
    -   [x] **Windows Subsystem for Linux**
    -   [x] **SMB Direct** (Optimizes file transfer)
    -   [x] **Work Folders Client**
3.  Click **OK** and wait for the process to finish.
4.  **🚨 RESTART YOUR PC NOW.**

### Option B: Using PowerShell (Administrator)
1.  **Open PowerShell as Administrator.**
2.  **Run these commands:**
    ```powershell
    # Enable WSL & Virtual Machine Platform
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

    # Enable SMB Direct & Work Folders
    dism.exe /online /enable-feature /featurename:SMB-Direct /all /norestart
    dism.exe /online /enable-feature /featurename:WorkFolders-Client /all /norestart
    ```
3.  **🚨 RESTART YOUR PC NOW.**

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

## ⚡ Option A: Quick Installation (Recommended)

> **⚠️ CRITICAL:** This command MUST be run inside your **Linux Terminal** (WSL), not PowerShell.

If your Linux distro is installed and you've created your user, run this:

```bash
# First, ensure curl is installed in Linux
sudo apt update && sudo apt install -y curl

# Run the automated installer
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/wsl-xfce/enterprise_installer.sh | bash
```

---

## 🐧 Option B: Manual Configuration (Step-by-Step)

Launch your Linux terminal and run these steps.

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
sudo apt install xfce4 xfce4-goodies xrdp -y

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

---

## 🔌 Step 4: Connect via Remote Desktop

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
**🎉 Setup Complete! Your WSL Desktop is ready.**
