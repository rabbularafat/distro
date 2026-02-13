# WSL2 Auto-Installer for Windows
# This script enables necessary features and installs Debian automatically.

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator!"
    Exit
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   WSL2 AUTOMATED FEATURE INSTALLER                " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Enable WSL and Virtual Machine Platform
Write-Host "[1/4] Enabling WSL & Virtual Machine Platform..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null

# Enable SMB Direct (Optional but recommended)
Write-Host "[2/4] Enabling SMB Direct..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:SMB-Direct /all /norestart | Out-Null

# Set WSL 2 as default
Write-Host "[3/4] Setting WSL 2 as default version..." -ForegroundColor Yellow
wsl --set-default-version 2

# Check if Debian is installed, if not, install it
if (!(wsl --list --quiet | Select-String "Debian")) {
    Write-Host "[4/4] Installing Debian Distro..." -ForegroundColor Yellow
    wsl --install -d Debian --no-launch
    Write-Host "✅ Debian installed successfully." -ForegroundColor Green
} else {
    Write-Host "[4/4] Debian is already installed." -ForegroundColor Green
}

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "✅ WINDOWS FEATURES ENABLED!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "🚨 RESTART IS REQUIRED to complete the setup." -ForegroundColor Red
Write-Host "After restart, run the Linux installer script inside your Debian terminal."
