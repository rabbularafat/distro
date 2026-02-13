# 🚫 Step 5: Disable WSLg (Optional)

WSLg (WSL Graphics) is the built-in way Windows handles Linux GUI apps. If you prefer using XRDP/XFCE exclusively or find WSLg is interfering, you can disable it globally.

## ✅ Option 1: Temporary Shutdown
Run in PowerShell:
```powershell
wsl --shutdown
```
Then restart your distro.

## ✅ Option 2: Disable WSLg Globally
1. In Windows, navigate to your user profile folder: `C:\Users\YOUR_USERNAME\`
2. Create or edit a file named `.wslconfig`.
3. Add the following content:
   ```ini
   [wsl2]
   guiApplications=false
   ```
4. Run `wsl --shutdown` in PowerShell.
5. Launch Debian again.

---
[Linux Setup Guide](./Step_6_Linux_Desktop_Setup.md)
