# 🔎 Step 3: Troubleshooting Virtualization Errors

If you see an error message stating that **Virtualization is not enabled**, you need to enable it in your computer's BIOS/UEFI settings.

## 🔹 How to Enable Virtualization

1. **Restart your PC.**
2. **Enter BIOS/UEFI:** Repeatedly press the BIOS key (usually `F2`, `F10`, `DEL`, or `Esc`) during startup.
3. **Locate CPU Configuration:** Look for "Advanced", "CPU Configuration", or "Security" tabs.
4. **Enable the Setting:**
   - **Intel CPUs:** Enable **Intel VT-x** or **Intel Virtualization Technology**.
   - **AMD CPUs:** Enable **SVM Mode** or **Secure Virtual Machine**.
5. **Save and Exit:** Press `F10` to save and exit.

## 🚀 Diagnostic Command
To check your current WSL status and see if virtualization is active, run this in PowerShell:
```powershell
wsl --status
```

---
[Back to Installation](./Step_2_WSL_Installation.md)
