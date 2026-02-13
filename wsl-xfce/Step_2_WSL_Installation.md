# 🚀 Step 2: Install WSL Properly

After restarting your PC, you can proceed with the WSL installation.

## 🔍 Check Your Windows Version
First, verify that your Windows version supports WSL 2.
1. In PowerShell, run:
   ```powershell
   winver
   ```
2. **Compatibility:**
   - **Windows 11:** Fully supported.
   - **Windows 10 Version 2004+ (Build 19041+):** Fully supported.
   - **Older Versions:** WSL 2 may not work properly. Please update Windows.

## 🔹 Installation Commands
Open **PowerShell** as **Administrator** and run:

```powershell
wsl --install
```

If the above command fails or you want to ensure version 2 is the default, run:
```powershell
wsl --set-default-version 2
```

## 🔹 Install Debian
Go to the **Microsoft Store**, search for **Debian**, and click **Get/Install**. Launch it once the download finishes to set up your username and password.

---
[Next Step: Troubleshooting Virtualization](./Step_3_Virtualization_Errors.md) | [Linux Setup](./Step_6_Linux_Desktop_Setup.md)
