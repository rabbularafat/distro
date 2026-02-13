# 🚀 Universal Linux XFCE4 Desktop (Native PC)

This repository contains the ultimate guide and automated scripts to set up a full **XFCE4 Desktop Environment** and **XRDP Remote Access** on real hardware running **Ubuntu** or **Debian**.

---

## ⚡ Quick Installation (Enterprise)

If your OS is already installed, run this single command to transform it into a desktop-ready system:

```bash
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/unix-xfce/enterprise_installer.sh | sudo bash
```

---

## 📖 Full Installation Guide (Step-by-Step)

Follow this comprehensive guide to set up your Linux Desktop from scratch.

### 🛠 Step 1: Hardware & BIOS Preparation

For a native Linux installation on a Real PC, you need to prepare your hardware.

1.  **Enter BIOS/UEFI**: Restart your PC and press the BIOS key (usually `F2`, `F10`, `Del`, or `Esc`).
2.  **Enable Virtualization**:
    - **Intel:** Enable **Intel VT-x** / **Intel Virtualization Technology**.
    - **AMD:** Enable **SVM Mode** / **Secure Virtual Machine**.
3.  **Secure Boot**: If you are installing a custom kernel or some drivers, you may need to **Disable Secure Boot**. (Modern Ubuntu/Debian support it, but it's good to know).
4.  **Boot Order**: Ensure your USB drive (installation media) is at the top of the boot priority list.

### 📦 Step 2: Linux OS Installation

This guide assumes you are using **Ubuntu** or **Debian**.

1.  **Download the ISO**:
    - [Ubuntu Desktop Download](https://ubuntu.com/download/desktop)
    - [Debian ISO Download](https://www.debian.org/distrib/)
2.  **Create Bootable USB**: Use [Rufus](https://rufus.ie/) (Windows) or `dd` (Linux) to flash the ISO to a USB drive.
3.  **Install the OS**: Boot from the USB, follow instructions, and create your **Username** and **Password**.

### 🔎 Step 3: Virtualization & Hardware Errors

1.  **"Virtualization not enabled"**: Verify **VT-x (Intel)** or **SVM (AMD)** is set to **Enabled** in BIOS.
2.  **Secure Boot Issues**: If drivers (like NVIDIA) won't load, try disabling **Secure Boot**.
3.  **Storage Errors**: Ensure SATA mode is set to **AHCI** (not RAID/Intel RST).

### 🐧 Step 6: Linux Desktop & XFCE Setup

Once your OS is running, run the following commands in the terminal:

1.  **Update System**:
    ```bash
    sudo apt update && sudo apt upgrade -y
    ```
2.  **Install XFCE4**:
    ```bash
    sudo apt install -y xfce4 xfce4-goodies dbus-x11
    ```

### 🖥️ Step 7: Remote Desktop Connection (XRDP)

1.  **Install XRDP**:
    ```bash
    sudo apt install -y xrdp
    ```
2.  **Configure Session**:
    ```bash
    echo "xfce4-session" > ~/.xsession
    chmod +x ~/.xsession
    ```
3.  **Fix X11 Permissions**:
    ```bash
    sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config
    ```
4.  **Enable and Start Service**:
    ```bash
    sudo systemctl enable xrdp
    sudo systemctl restart xrdp
    ```

---

## 🔌 Reconnecting to Your Desktop

1.  **Find Your IP Address**: Run `hostname -I` on your Linux machine.
2.  **Open Windows RDP**: Press `Win + R`, type `mstsc`, and Enter.
3.  **Login**: Use your Linux IP, Username, and Password.
4.  **Firewall Fix**: If connection fails, run `sudo ufw allow 3389/tcp`.

---

## 🏁 Summary
- **Native Installation**: Follow the steps above.
- **Enterprise Script**: Use the `curl` command at the top.
- **XRDP Ready**: Pre-configured for a smooth remote experience.
