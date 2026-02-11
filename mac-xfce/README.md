# macOS XFCE4 Desktop (via Multipass)

Because macOS does not run XFCE natively on its Aqua window manager, this installer uses **Multipass** to create a lightweight Ubuntu VM and sets up XFCE + XRDP for you.

## 🚀 Installation

Run this in your macOS terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/rabbularafat/distro/main/mac-xfce/setup.sh | bash
```

## 📦 What it does
1. Installs **Homebrew** (if missing).
2. Installs **Multipass** (if missing).
3. Launches a Linux instance optimized for desktop use.
4. Installs **XFCE4** and **XRDP** inside the instance.

## 🏁 Connection
1. Note the IP address shown at the end of the script.
2. Install **Microsoft Remote Desktop** from the Mac App Store.
3. Connect to the IP and use the username `ubuntu`.

## 🛠 Useful Commands
- **Launch Shell:** `multipass shell mac-xfce-desktop`
- **Stop VM:** `multipass stop mac-xfce-desktop`
- **Delete VM:** `multipass delete --purge mac-xfce-desktop`
