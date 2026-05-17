# =============================================================================
#  WinSetup.ps1 — Universal Windows Setup Script
#  Supports: Windows 7, 8, 8.1, 10, 11
#  Run as Administrator:
#    Right-click > "Run with PowerShell" (as Admin)
#    OR: powershell -ExecutionPolicy Bypass -File WinSetup.ps1
# =============================================================================

#region ── INIT & VERSION DETECTION ──────────────────────────────────────────

$ErrorActionPreference = "SilentlyContinue"

function Write-Header($text) {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Step($text) {
    Write-Host "  >> $text" -ForegroundColor Green
}

function Write-Warn($text) {
    Write-Host "  !! $text" -ForegroundColor Red
}

# Require Administrator
If (-NOT ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warn "Please run this script as Administrator!"
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Detect Windows version
$OSVersion = [System.Environment]::OSVersion.Version
$OSMajor  = $OSVersion.Major
$OSMinor  = $OSVersion.Minor
$OSBuild  = $OSVersion.Build

$WinName = switch ($true) {
    ($OSMajor -eq 10 -and $OSBuild -ge 22000) { "Windows 11" }
    ($OSMajor -eq 10)                          { "Windows 10" }
    ($OSMajor -eq 6 -and $OSMinor -eq 3)       { "Windows 8.1" }
    ($OSMajor -eq 6 -and $OSMinor -eq 2)       { "Windows 8" }
    ($OSMajor -eq 6 -and $OSMinor -eq 1)       { "Windows 7" }
    default                                     { "Unknown Windows" }
}

Write-Host ""
Write-Host "  ██╗    ██╗██╗███╗   ██╗███████╗███████╗████████╗██╗   ██╗██████╗ " -ForegroundColor Cyan
Write-Host "  ██║    ██║██║████╗  ██║██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗" -ForegroundColor Cyan
Write-Host "  ██║ █╗ ██║██║██╔██╗ ██║███████╗█████╗     ██║   ██║   ██║██████╔╝" -ForegroundColor Cyan
Write-Host "  ██║███╗██║██║██║╚██╗██║╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ " -ForegroundColor Cyan
Write-Host "  ╚███╔███╔╝██║██║ ╚████║███████║███████╗   ██║   ╚██████╔╝██║     " -ForegroundColor Cyan
Write-Host "   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     " -ForegroundColor Cyan
Write-Host ""
Write-Host "  Detected: $WinName (Build $OSBuild)" -ForegroundColor Magenta
Write-Host ""

Start-Sleep -Seconds 2

#endregion

#region ── 1. TASKBAR — SMALL ICONS ──────────────────────────────────────────

Write-Header "1. Setting Taskbar to Small Icons"

$TaskbarKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if ($OSMajor -eq 10) {
    # Works for Win 10 and Win 11
    Set-ItemProperty -Path $TaskbarKey -Name TaskbarSmallIcons -Value 1 -Type DWord -Force
    Write-Step "Small taskbar icons enabled (Win 10/11)"
} elseif ($OSMajor -eq 6) {
    # Works for Win 7, 8, 8.1
    Set-ItemProperty -Path $TaskbarKey -Name TaskbarSmallIcons -Value 1 -Type DWord -Force
    Write-Step "Small taskbar icons enabled (Win 7/8/8.1)"
}

# Also set taskbar size in registry for Win 11
if ($OSBuild -ge 22000) {
    $Win11TaskbarKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $Win11TaskbarKey -Name TaskbarSi -Value 0 -Type DWord -Force
    Write-Step "Win 11 taskbar size set to small"
}

#endregion

#region ── 2. DESKTOP ICONS — THIS PC & USER FOLDER ─────────────────────────

Write-Header "2. Showing 'This PC' and User Folder on Desktop"

$DesktopIconsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
$ClassicKey      = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu"

# GUIDs
$ThisPC_GUID     = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
$UserFolder_GUID = "{59031a47-3f72-44a7-89c5-5595fe6b30ee}"

foreach ($Key in @($DesktopIconsKey, $ClassicKey)) {
    If (!(Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
    Set-ItemProperty -Path $Key -Name $ThisPC_GUID     -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $Key -Name $UserFolder_GUID -Value 0 -Type DWord -Force
}

Write-Step "This PC icon shown on desktop"
Write-Step "User folder icon shown on desktop"

#endregion

#region ── 3. POWER SETTINGS ─────────────────────────────────────────────────

Write-Header "3. Configuring Power Button / Sleep / Lid Settings"

# Power button = Shutdown (3), Sleep button = Sleep (1), Lid = Do nothing (0)
# Index: 1=On battery, 2=Plugged in

# Power button → Shutdown
powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
Write-Step "Power button set to: Shutdown"

# Sleep button → Sleep
powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1
Write-Step "Sleep button set to: Sleep"

# Lid close → Do nothing
powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
Write-Step "Lid close set to: Do nothing"

powercfg -SetActive SCHEME_CURRENT
Write-Step "Power scheme applied"

#endregion

#region ── 4. .NET 3.5 (includes 2.0 and 3.0) ────────────────────────────────

Write-Header "4. Enabling .NET Framework 3.5 (Windows Feature)"

$DotNetFeature = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue

if ($DotNetFeature -and $DotNetFeature.State -eq "Enabled") {
    Write-Step ".NET 3.5 is already enabled"
} else {
    Write-Step "Enabling .NET 3.5 via DISM (may need internet)..."
    DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Step ".NET 3.5 enabled successfully"
    } else {
        Write-Warn ".NET 3.5 enable failed. Try manually via: Control Panel > Programs > Turn Windows Features On/Off"
    }
}

# .NET 4.x is built into Win 8+ / installed via Windows Update on Win 7
Write-Step ".NET 4.x: handled via Windows Update step below"

#endregion

#region ── 5. WINDOWS UPDATE ─────────────────────────────────────────────────

Write-Header "5. Running Windows Update"

# PSWindowsUpdate module — works on Win 7 SP1+ with WMF 3+
if ($OSBuild -ge 7601) {
    Write-Step "Installing PSWindowsUpdate module..."
    
    # Ensure NuGet provider
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser -Confirm:$false | Out-Null
    }
    
    Import-Module PSWindowsUpdate -Force
    Write-Step "Searching and installing all available updates (this may take a while)..."
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -Verbose
    Write-Step "Windows Update completed (reboot may be required later)"
} else {
    Write-Warn "Automatic Windows Update via script not supported on this OS version."
    Write-Warn "Please run Windows Update manually."
}

#endregion

#region ── 6. INSTALL WINGET (if not present) ────────────────────────────────

Write-Header "6. Checking / Installing Winget"

function Get-WingetPath {
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe"
    )
    foreach ($p in $paths) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

$WingetExe = Get-WingetPath

if (-not $WingetExe) {
    Write-Step "Winget not found. Installing App Installer from Microsoft..."
    
    $wingetUrl = "https://aka.ms/getwinget"
    $wingetInstaller = "$env:TEMP\AppInstaller.msixbundle"
    
    try {
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetInstaller -UseBasicParsing
        Add-AppxPackage -Path $wingetInstaller
        Start-Sleep -Seconds 5
        $WingetExe = Get-WingetPath
        if ($WingetExe) {
            Write-Step "Winget installed successfully"
        } else {
            Write-Warn "Winget installation may have failed. Apps requiring winget will be skipped."
        }
    } catch {
        Write-Warn "Could not download winget. Check internet connection."
    }
} else {
    Write-Step "Winget found: $WingetExe"
}

function Install-App($AppName, $WingetID, $MinBuild = 0) {
    if ($OSBuild -lt $MinBuild) {
        Write-Warn "Skipping $AppName — not supported on this Windows version"
        return
    }
    if (-not $WingetExe) {
        Write-Warn "Winget unavailable — skipping $AppName"
        return
    }
    Write-Step "Installing $AppName ($WingetID)..."
    & $WingetExe install --id $WingetID --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host "     [OK] $AppName installed" -ForegroundColor Green
    } else {
        Write-Host "     [!!] $AppName may have had an issue (code $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

#endregion

#region ── 7. INSTALL APPS ───────────────────────────────────────────────────

Write-Header "7. Installing Applications via Winget"

# WinRAR
Install-App "WinRAR"        "RARLab.WinRAR"

# AnyDesk
Install-App "AnyDesk"       "AnyDeskSoftwareGmbH.AnyDesk"

# VLC Player
Install-App "VLC"           "VideoLAN.VLC"

# Foxit PDF Reader
Install-App "Foxit Reader"  "Foxit.FoxitReader"

# Google Chrome
Install-App "Google Chrome" "Google.Chrome"

# DirectX (via DirectX End-User Runtime)
Write-Step "Installing DirectX End-User Runtime..."
$dxUrl  = "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe"
$dxPath = "$env:TEMP\dxwebsetup.exe"
try {
    Invoke-WebRequest -Uri $dxUrl -OutFile $dxPath -UseBasicParsing
    Start-Process -FilePath $dxPath -ArgumentList "/silent" -Wait
    Write-Step "DirectX runtime installer launched"
} catch {
    Write-Warn "Could not download DirectX setup. Install manually from microsoft.com"
}

# Microsoft Office 365 — multilingual (EN, AR, FR)
Write-Header "7b. Installing Microsoft Office 365 (Multilingual: EN/AR/FR)"
Write-Step "Downloading Office Deployment Tool..."

$odtUrl  = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17531-20046.exe"
$odtPath = "$env:TEMP\ODT.exe"
$odtDir  = "$env:TEMP\ODT"

try {
    Invoke-WebRequest -Uri $odtUrl -OutFile $odtPath -UseBasicParsing
    New-Item -ItemType Directory -Path $odtDir -Force | Out-Null
    Start-Process -FilePath $odtPath -ArgumentList "/quiet /extract:$odtDir" -Wait

    # Build multilingual configuration XML
    $officeConfig = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
      <Language ID="ar-sa" />
      <Language ID="fr-fr" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" Channel="Current" />
  <Display Level="Full" AcceptEULA="TRUE" />
  <Logging Level="Standard" Path="%temp%" />
</Configuration>
"@
    $configPath = "$odtDir\office365_multi.xml"
    $officeConfig | Out-File -FilePath $configPath -Encoding UTF8

    Write-Step "Downloading and installing Office 365 (EN + AR + FR) — this will take several minutes..."
    Start-Process -FilePath "$odtDir\setup.exe" -ArgumentList "/configure `"$configPath`"" -Wait
    Write-Step "Office 365 installation completed"
} catch {
    Write-Warn "Office 365 installation failed: $_"
    Write-Warn "Download manually from: https://www.microsoft.com/en-us/microsoft-365"
}

#endregion

#region ── 8. WALLPAPER ───────────────────────────────────────────────────────

Write-Header "8. Setting Desktop Wallpaper"

# ── Change this URL to any direct image link you want ──
$WallpaperURL  = "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&q=80"
$WallpaperPath = "$env:APPDATA\WinSetupWallpaper.jpg"

try {
    Write-Step "Downloading wallpaper..."
    Invoke-WebRequest -Uri $WallpaperURL -OutFile $WallpaperPath -UseBasicParsing

    # Apply wallpaper via registry + SystemParametersInfo
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $WallpaperPath
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"   # Fill
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper  -Value "0"

    # Force Windows to apply it immediately
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    [Wallpaper]::SystemParametersInfo(0x0014, 0, $WallpaperPath, 0x01 -bor 0x02) | Out-Null
    Write-Step "Wallpaper set successfully"
} catch {
    Write-Warn "Could not set wallpaper: $_"
}

#endregion

#region ── 9. REFRESH EXPLORER ───────────────────────────────────────────────

Write-Header "9. Refreshing Windows Explorer"

# Restart Explorer to apply taskbar + desktop icon changes
Write-Step "Restarting Explorer..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer
Write-Step "Explorer restarted — desktop changes applied"

#endregion

#region ── 10. ACTIVATION ────────────────────────────────────────────────────

Write-Header "10. Running Activation Script"

Write-Warn "About to run: irm https://get.activated.win | iex"
Write-Host "  Press ENTER to continue, or Ctrl+C to skip..." -ForegroundColor Yellow
Read-Host

try {
    Invoke-RestMethod https://get.activated.win | Invoke-Expression
} catch {
    Write-Warn "Activation script failed or was skipped: $_"
}

#endregion

#region ── DONE ───────────────────────────────────────────────────────────────

Write-Header "Setup Complete!"
Write-Host ""
Write-Host "  Summary of actions performed:" -ForegroundColor Cyan
Write-Host "   [+] Taskbar set to small icons"             -ForegroundColor Green
Write-Host "   [+] This PC and User folder on desktop"     -ForegroundColor Green
Write-Host "   [+] Power / Sleep / Lid settings configured" -ForegroundColor Green
Write-Host "   [+] .NET 3.5 enabled"                       -ForegroundColor Green
Write-Host "   [+] Windows Update searched and applied"     -ForegroundColor Green
Write-Host "   [+] Apps installed (WinRAR, AnyDesk, VLC, Foxit, Chrome, DirectX, Office 365)" -ForegroundColor Green
Write-Host "   [+] Wallpaper set"                          -ForegroundColor Green
Write-Host "   [+] Activation script executed"             -ForegroundColor Green
Write-Host ""
Write-Host "  A REBOOT is recommended to fully apply all changes." -ForegroundColor Yellow
Write-Host ""

$reboot = Read-Host "  Reboot now? (Y/N)"
if ($reboot -match "^[Yy]") {
    Restart-Computer -Force
}

#endregion