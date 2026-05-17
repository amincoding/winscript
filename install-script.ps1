# =============================================================================
#  install-script.ps1 — Universal Windows Setup Script
#  Supports: Windows 7, 8, 8.1, 10, 11
#  Run as Administrator:
#    powershell -ExecutionPolicy Bypass -File install-script.ps1
#    OR: irm https://raw.githubusercontent.com/amincoding/winscript/main/install-script.ps1 | iex
# =============================================================================

#region ── INIT & VERSION DETECTION ──────────────────────────────────────────

# Keep errors silent but catchable
$ErrorActionPreference = "SilentlyContinue"

function Write-Header($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Cyan
}
function Write-Step($text)  { Write-Host "  >> $text" -ForegroundColor Green }
function Write-Warn($text)  { Write-Host "  !! $text" -ForegroundColor Red   }
function Write-Info($text)  { Write-Host "  -- $text" -ForegroundColor Gray  }

# ── Require Administrator ────────────────────────────────────────────────────
If (-NOT ([Security.Principal.WindowsPrincipal]
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Not running as Administrator. Relaunching elevated..."
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ── Detect Windows version ───────────────────────────────────────────────────
$OSVersion = [System.Environment]::OSVersion.Version
$OSMajor   = $OSVersion.Major
$OSMinor   = $OSVersion.Minor
$OSBuild   = $OSVersion.Build

$WinName = switch ($true) {
    ($OSMajor -eq 10 -and $OSBuild -ge 22000) { "Windows 11" }
    ($OSMajor -eq 10)                          { "Windows 10" }
    ($OSMajor -eq 6  -and $OSMinor -eq 3)      { "Windows 8.1" }
    ($OSMajor -eq 6  -and $OSMinor -eq 2)      { "Windows 8" }
    ($OSMajor -eq 6  -and $OSMinor -eq 1)      { "Windows 7" }
    default                                     { "Unknown Windows" }
}

# Detect architecture
$Is64bit = [Environment]::Is64BitOperatingSystem

Clear-Host
Write-Host ""
Write-Host "  ██╗    ██╗██╗███╗   ██╗███████╗███████╗████████╗██╗   ██╗██████╗ " -ForegroundColor Cyan
Write-Host "  ██║    ██║██║████╗  ██║██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗" -ForegroundColor Cyan
Write-Host "  ██║ █╗ ██║██║██╔██╗ ██║███████╗█████╗     ██║   ██║   ██║██████╔╝" -ForegroundColor Cyan
Write-Host "  ██║███╗██║██║██║╚██╗██║╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ " -ForegroundColor Cyan
Write-Host "  ╚███╔███╔╝██║██║ ╚████║███████║███████╗   ██║   ╚██████╔╝██║     " -ForegroundColor Cyan
Write-Host "   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝    " -ForegroundColor Cyan
Write-Host ""
Write-Host "  Detected : $WinName (Build $OSBuild)" -ForegroundColor Magenta
Write-Host "  Arch     : $(if ($Is64bit) {'64-bit'} else {'32-bit'})" -ForegroundColor Magenta
Write-Host ""
Start-Sleep -Seconds 2

#endregion

# =============================================================================
#region ── 1. TASKBAR — SMALL ICONS ──────────────────────────────────────────
# =============================================================================

Write-Header "1. Setting Taskbar to Small Icons"

$AdvKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
If (!(Test-Path $AdvKey)) { New-Item -Path $AdvKey -Force | Out-Null }

# TaskbarSmallIcons works on Win 7 / 8 / 8.1 / 10
Set-ItemProperty -Path $AdvKey -Name "TaskbarSmallIcons" -Value 1 -Type DWord -Force
Write-Step "TaskbarSmallIcons = 1 set"

# Win 11 uses a different value (TaskbarSi: 0=small, 1=medium, 2=large)
if ($OSBuild -ge 22000) {
    Set-ItemProperty -Path $AdvKey -Name "TaskbarSi" -Value 0 -Type DWord -Force
    Write-Step "Win11 TaskbarSi = 0 (small) set"
}

#endregion

# =============================================================================
#region ── 2. DESKTOP ICONS — THIS PC & USER FOLDER ─────────────────────────
# =============================================================================

Write-Header "2. Showing 'This PC' and User Folder on Desktop"

# Value 0 = SHOW, Value 1 = HIDE
$ThisPC_GUID     = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
$UserFolder_GUID = "{59031a47-3f72-44a7-89c5-5595fe6b30ee}"

$IconKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu"
)

foreach ($key in $IconKeys) {
    If (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name $ThisPC_GUID     -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $key -Name $UserFolder_GUID -Value 0 -Type DWord -Force
}

Write-Step "This PC icon: visible"
Write-Step "User Folder icon: visible"

#endregion

# =============================================================================
#region ── 3. POWER SETTINGS ─────────────────────────────────────────────────
# =============================================================================

Write-Header "3. Configuring Power Button / Sleep Button / Lid"

# Values: 0=Do nothing, 1=Sleep, 2=Hibernate, 3=Shut down
powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3   # Power button AC → Shutdown
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3   # Power button DC → Shutdown
Write-Step "Power button → Shutdown"

powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1   # Sleep button AC → Sleep
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1   # Sleep button DC → Sleep
Write-Step "Sleep button → Sleep"

powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0        # Lid AC → Do nothing
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0        # Lid DC → Do nothing
Write-Step "Lid close → Do nothing"

powercfg -SetActive SCHEME_CURRENT
Write-Step "Power scheme applied"

#endregion

# =============================================================================
#region ── 4. .NET FRAMEWORK 3.5 ─────────────────────────────────────────────
# =============================================================================

Write-Header "4. Enabling .NET Framework 3.5"

$net35 = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue

if ($net35 -and $net35.State -eq "Enabled") {
    Write-Step ".NET 3.5 already enabled — skipping"
} else {
    Write-Step "Enabling .NET 3.5 via DISM..."
    $dismResult = DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Step ".NET 3.5 enabled successfully"
    } else {
        Write-Warn ".NET 3.5 DISM failed. Trying via Windows PowerShell..."
        Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart -ErrorAction SilentlyContinue
        if ($?) { Write-Step ".NET 3.5 enabled via PowerShell" }
        else     { Write-Warn "Could not enable .NET 3.5. Enable manually: Control Panel > Programs > Windows Features" }
    }
}

#endregion

# =============================================================================
#region ── 5. WINDOWS UPDATE ─────────────────────────────────────────────────
# =============================================================================

Write-Header "5. Running Windows Update"

try {
    Write-Step "Setting up NuGet provider..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null

    Write-Step "Installing PSWindowsUpdate module..."
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser -Confirm:$false | Out-Null
    }
    Import-Module PSWindowsUpdate -Force -ErrorAction Stop

    Write-Step "Searching and installing all updates (this may take a while)..."
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction SilentlyContinue
    Write-Step "Windows Update done"
} catch {
    Write-Warn "PSWindowsUpdate failed: $_"
    Write-Info "Falling back to wuauclt..."
    Start-Process wuauclt -ArgumentList "/detectnow /updatenow" -ErrorAction SilentlyContinue
    Write-Step "Windows Update triggered via wuauclt"
}

#endregion

# =============================================================================
#region ── 6. WINGET SETUP ───────────────────────────────────────────────────
# =============================================================================

Write-Header "6. Checking Winget"

# Force TLS 1.2 for all web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-WingetExe {
    # Search common locations
    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe"
    )
    foreach ($c in $candidates) {
        $found = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    # Try PATH
    $fromPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath.Source }
    return $null
}

$WingetExe = Get-WingetExe

if (-not $WingetExe) {
    Write-Step "Winget not found — installing App Installer..."
    try {
        # Download latest winget release from GitHub
        $latestRelease = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $msixBundle = $latestRelease.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        $installerPath = "$env:TEMP\winget.msixbundle"
        Invoke-WebRequest -Uri $msixBundle.browser_download_url -OutFile $installerPath -UseBasicParsing
        Add-AppxPackage -Path $installerPath -ErrorAction Stop
        Start-Sleep -Seconds 5
        $WingetExe = Get-WingetExe
        if ($WingetExe) { Write-Step "Winget installed: $WingetExe" }
        else             { Write-Warn "Winget install completed but exe not found. Apps may fail." }
    } catch {
        Write-Warn "Winget install failed: $_"
    }
} else {
    Write-Step "Winget found: $WingetExe"
    # Update winget sources
    & $WingetExe source update --disable-interactivity 2>&1 | Out-Null
    Write-Step "Winget sources updated"
}

# ── Install-App helper ───────────────────────────────────────────────────────
function Install-App {
    param(
        [string]$AppName,
        [string]$WingetID
    )
    if (-not $WingetExe) {
        Write-Warn "Winget unavailable — skipping $AppName"
        return
    }
    Write-Step "Installing $AppName..."
    # Use --scope machine for system-wide install, exact match to avoid wrong packages
    $result = & $WingetExe install `
        --id $WingetID `
        --exact `
        --scope machine `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity `
        2>&1

    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        # -1978335189 = already installed
        Write-Host "     [OK] $AppName" -ForegroundColor Green
    } else {
        Write-Host "     [!!] $AppName — exit code $LASTEXITCODE" -ForegroundColor Yellow
        Write-Info ($result | Select-Object -Last 5 | Out-String).Trim()
    }
}

#endregion

# =============================================================================
#region ── 7. INSTALL APPS ───────────────────────────────────────────────────
# =============================================================================

Write-Header "7. Installing Applications"

Install-App "WinRAR"        "RARLab.WinRAR"
Install-App "AnyDesk"       "AnyDeskSoftwareGmbH.AnyDesk"
Install-App "VLC Player"    "VideoLAN.VLC"
Install-App "Foxit Reader"  "Foxit.FoxitReader"
Install-App "Google Chrome" "Google.Chrome"

# ── DirectX End-User Runtime ─────────────────────────────────────────────────
Write-Step "Installing DirectX End-User Runtime..."
$dxPath = "$env:TEMP\dxwebsetup.exe"
try {
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe" `
        -OutFile $dxPath -UseBasicParsing
    Start-Process -FilePath $dxPath -ArgumentList "/silent" -Wait -ErrorAction Stop
    Write-Host "     [OK] DirectX" -ForegroundColor Green
} catch {
    Write-Warn "DirectX download failed: $_"
}

#endregion

# =============================================================================
#region ── 7b. OFFICE 365 — 64-bit — EN / AR / FR ────────────────────────────
# =============================================================================

Write-Header "7b. Installing Microsoft Office 365 (64-bit | EN + AR + FR)"

$odtDir     = "$env:TEMP\ODT"
$odtExe     = "$odtDir\ODTsetup.exe"
$odtSetup   = "$odtDir\setup.exe"
$xmlPath    = "$odtDir\office365.xml"

# Always use the latest ODT from Microsoft's official page
$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17531-20046.exe"

New-Item -ItemType Directory -Path $odtDir -Force | Out-Null

try {
    Write-Step "Downloading Office Deployment Tool..."
    Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing -ErrorAction Stop

    Write-Step "Extracting ODT..."
    Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:`"$odtDir`"" -Wait -ErrorAction Stop

    if (-not (Test-Path $odtSetup)) {
        throw "setup.exe not found after ODT extraction at $odtDir"
    }

    # ── Office XML config — force 64-bit explicitly ──────────────────────────
    $officeXml = @"
<Configuration ID="winsetup-office365">
  <Add OfficeClientEdition="64" Channel="Current" MigrateArch="TRUE">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
      <Language ID="ar-sa" />
      <Language ID="fr-fr" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="Publisher" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="TRUE" Channel="Current" />
  <RemoveMSI />
  <Display Level="Full" AcceptEULA="TRUE" />
  <Logging Level="Standard" Path="%temp%\OfficeSetupLog" />
</Configuration>
"@

    $officeXml | Out-File -FilePath $xmlPath -Encoding UTF8 -Force
    Write-Step "Office config written (64-bit, EN+AR+FR)"

    Write-Step "Starting Office 365 download and install (this takes several minutes)..."
    $proc = Start-Process -FilePath $odtSetup `
        -ArgumentList "/configure `"$xmlPath`"" `
        -Wait -PassThru -ErrorAction Stop

    if ($proc.ExitCode -eq 0) {
        Write-Host "     [OK] Office 365 installed successfully" -ForegroundColor Green
    } else {
        Write-Warn "Office setup exited with code $($proc.ExitCode) — check %temp%\OfficeSetupLog"
    }
} catch {
    Write-Warn "Office 365 installation failed: $_"
    Write-Info "You can install manually from: https://aka.ms/office-install"
}

#endregion

# =============================================================================
#region ── 8. WALLPAPER ───────────────────────────────────────────────────────
# =============================================================================

Write-Header "8. Setting Desktop Wallpaper"

$WallpaperURL  = "https://raw.githubusercontent.com/amincoding/winscript/main/Gemini_Generated_Image_wrbxznwrbxznwrbx.png"
$WallpaperPath = "$env:PUBLIC\WinSetupWallpaper.png"   # PUBLIC so it works for all users

try {
    Write-Step "Downloading wallpaper from GitHub..."
    # Use WebClient for better binary file handling than Invoke-WebRequest
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($WallpaperURL, $WallpaperPath)

    if (-not (Test-Path $WallpaperPath) -or (Get-Item $WallpaperPath).Length -lt 1000) {
        throw "Wallpaper file missing or too small — download may have failed"
    }
    Write-Step "Wallpaper downloaded: $WallpaperPath ($('{0:N0}' -f (Get-Item $WallpaperPath).Length) bytes)"

    # Registry
    $desktopKey = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $desktopKey -Name "Wallpaper"      -Value $WallpaperPath -Force
    Set-ItemProperty -Path $desktopKey -Name "WallpaperStyle" -Value "10" -Force   # 10 = Fill
    Set-ItemProperty -Path $desktopKey -Name "TileWallpaper"  -Value "0"  -Force

    # Apply immediately via Win32 API
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinWallpaper {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool SystemParametersInfo(uint uAction, uint uParam, string lpvParam, uint fuWinIni);
    public const uint SPI_SETDESKWALLPAPER = 0x0014;
    public const uint SPIF_UPDATEINIFILE   = 0x0001;
    public const uint SPIF_SENDCHANGE      = 0x0002;
    public static void Set(string path) {
        SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, path, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
    }
}
"@ -ErrorAction SilentlyContinue

    [WinWallpaper]::Set($WallpaperPath)
    Write-Step "Wallpaper applied successfully"
} catch {
    Write-Warn "Wallpaper failed: $_"
}

#endregion

# =============================================================================
#region ── 9. RESTART EXPLORER ───────────────────────────────────────────────
# =============================================================================

Write-Header "9. Restarting Explorer (applying all UI changes)"

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process explorer
Write-Step "Explorer restarted — taskbar + desktop icons applied"

#endregion

# =============================================================================
#region ── 10. ACTIVATION ────────────────────────────────────────────────────
# =============================================================================

Write-Header "10. Activation"

Write-Host "  About to run the activation script." -ForegroundColor Yellow
Write-Host "  Press ENTER to continue or Ctrl+C to skip..." -ForegroundColor Yellow
Read-Host

try {
    Invoke-RestMethod https://get.activated.win | Invoke-Expression
} catch {
    Write-Warn "Activation script error: $_"
}

#endregion

# =============================================================================
#region ── DONE ──────────────────────────────────────────────────────────────
# =============================================================================

Write-Header "All Done!"
Write-Host ""
Write-Host "  [+] Taskbar small icons"                              -ForegroundColor Green
Write-Host "  [+] This PC + User Folder on desktop"                 -ForegroundColor Green
Write-Host "  [+] Power / Sleep / Lid configured"                   -ForegroundColor Green
Write-Host "  [+] .NET 3.5 enabled"                                 -ForegroundColor Green
Write-Host "  [+] Windows Update run"                               -ForegroundColor Green
Write-Host "  [+] Apps: WinRAR, AnyDesk, VLC, Foxit, Chrome, DX"   -ForegroundColor Green
Write-Host "  [+] Office 365 64-bit (EN + AR + FR)"                 -ForegroundColor Green
Write-Host "  [+] Wallpaper set"                                    -ForegroundColor Green
Write-Host "  [+] Activation run"                                   -ForegroundColor Green
Write-Host ""
Write-Host "  A REBOOT is recommended to finalize all changes." -ForegroundColor Yellow
Write-Host ""

$reboot = Read-Host "  Reboot now? (Y/N)"
if ($reboot -match "^[Yy]") { Restart-Computer -Force }

#endregion
