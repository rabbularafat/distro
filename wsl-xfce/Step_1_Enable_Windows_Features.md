# 🛠 Step 1: Enable Required Windows Features

To use WSL 2 and run a Linux Desktop Environment, you must enable the underlying Windows features.

## 🔹 Instructions

1. Open **PowerShell** as **Administrator**.
2. Run the following command to enable the Linux Subsystem:
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   ```
3. Run the following command to enable the Virtual Machine Platform:
   ```powershell
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```

## 🔹 Restart Required
After running these commands, you **MUST** restart your PC for the changes to take effect.

---
[Next Step: WSL Installation](./Step_2_WSL_Installation.md)
