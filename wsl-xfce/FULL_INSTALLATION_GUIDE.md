# 🏁 FULL PROCESS — Windows 10/11 + WSL2 + XFCE + XRDP

This guide provides the complete, step-by-step process to set up a full Linux Desktop Environment (XFCE) on Windows using WSL 2 and XRDP.

---

## 🔹 STEP 1 — Enable Windows Features (PowerShell Admin)
```powershell
# Enable WSL
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine Platform
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```
**RESTART YOUR PC NOW.**

---

## 🔹 STEP 2 — Install WSL & Debian (PowerShell Admin)
1. Check version support: `winver` (Need Win 10 2004+ or Win 11).
2. Install WSL:
   ```powershell
   wsl --install
   wsl --set-default-version 2
   ```
3. Download **Debian** from the Microsoft Store and open it to set your username/password.

---

## 🔹 STEP 3 — Enable systemd inside Debian (Inside Debian)
`xrdp` requires systemd.
Inside Debian:
```bash
sudo apt update
sudo apt install -y curl wget gnupg2

sudo nano /etc/wsl.conf
```
Add:
```ini
[boot]
systemd=true
```
**Shutdown WSL in PowerShell:** `wsl --shutdown`
Then reopen Debian.

---

## 🔹 STEP 4 — User & Desktop Setup (Inside Debian)
1. **Create Remote User (Optional):**
   ```bash
   sudo adduser remote
   sudo usermod -aG sudo,adm remote
   ```
2. **Install XFCE Desktop:**
   ```bash
   sudo apt update
   sudo apt upgrade -y
   sudo apt install xfce4 xfce4-goodies -y
   sudo systemctl set-default graphical.target
   ```

---

## 🔹 STEP 5 — Install & Configure XRDP (Inside Debian)
```bash
sudo apt install xrdp -y

# Set XFCE as the default session
echo xfce4-session > ~/.xsession
chmod +x ~/.xsession

# Fix permissions
sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config

# Start Service
sudo systemctl enable xrdp
sudo systemctl start xrdp
```

---

## 🔹 STEP 6 — Connect from Windows
1. **Get IP:** Run `ip a | grep eth0` in Debian.
2. **Open MSTSC:** Press `Win+R`, type `mstsc`.
3. **Connect:** Paste the IP and login with your Linux credentials.

---

## ❓ Troubleshooting & Optimization

### Virtualization Error
If "Virtualization not enabled" appears:
- Restart -> Enter BIOS -> Enable **SVM Mode** (AMD) or **Intel VT-x** (Intel).

### Disable WSLg (Optional)
To prevent WSLg from interfering, create `C:\Users\YOUR_NAME\.wslconfig`:
```ini
[wsl2]
guiApplications=false
```
Then run `wsl --shutdown`.

### Dependency Errors
If `curl` or other tools are missing:
```bash
sudo apt install curl wget gnupg2 -y
```

---
**Enjoy your WSL Desktop!** 🚀
