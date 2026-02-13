# 🔄 Step 4: Quick Diagnostics & Restarting WSL

Sometimes WSL needs a full restart to apply changes (like enabling `systemd` or fixing network issues).

## ✅ What You Need To Do

1. **Close all Linux terminals** (Debian, etc.) completely.
2. **Open Windows PowerShell** (NOT Debian).
   - Press `Start` -> type `PowerShell` -> open it.
3. **Shutdown WSL:**
   ```powershell
   wsl --shutdown
   ```
   *This fully restarts the WSL subsystem.*
4. **Launch Debian again** from the Start menu.

## 🚀 Get Your IP Address
To connect via Remote Desktop, you need the internal WSL IP address. Inside the Debian terminal, run:
```bash
ip addr | grep eth0
```
Look for the line starting with `inet`. It will look something like:
`inet 172.25.XXX.XXX/20`

**Copy the IP (e.g., 172.25.123.45) for use in Remote Desktop.**

---
[Disable WSLg](./Step_5_WSLg_Global_Config.md)
