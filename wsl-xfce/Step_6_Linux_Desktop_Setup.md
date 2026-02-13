# 🐧 Step 6: Debian XFCE + XRDP Setup

This step installs the Desktop Environment and Remote Desktop server inside your Debian WSL instance.

## 🔹 1. Enable systemd
`xrdp` requires `systemd` to work properly.
Inside Debian:
```bash
sudo apt update
sudo apt install -y curl wget gnupg2 software-properties-common

sudo nano /etc/wsl.conf
```
Add these lines:
```ini
[boot]
systemd=true
```
Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).
**In PowerShell, run `wsl --shutdown` and then reopen Debian.**

## 🔹 2. Create a Remote User (Optional)
If you want a dedicated user for RDP:
```bash
sudo adduser remote
sudo usermod -aG sudo,adm remote
```

## 🔹 3. Install XFCE4 Desktop
```bash
sudo apt update
sudo apt upgrade -y
sudo apt install xfce4 xfce4-goodies -y
sudo systemctl set-default graphical.target
```

## 🔹 4. Install and Configure XRDP
```bash
sudo apt install xrdp -y

# Configure XRDP to use XFCE
echo xfce4-session > ~/.xsession
chmod +x ~/.xsession

# Fix Xwrapper permissions
sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config

# Enable and Start the service
sudo systemctl enable xrdp
sudo systemctl start xrdp
```

## 🔹 4. Verify XRDP Status
```bash
sudo systemctl status xrdp
```
It should say `active (running)`.

---
[Final Step: Remote Desktop Connection](./Step_7_Remote_Desktop_Connection.md)
