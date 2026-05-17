# =============================================================================
#  install-script.ps1 - Universal Windows Setup Script
#  Supports: Windows 7, 8, 8.1, 10, 11
#  Run: irm https://raw.githubusercontent.com/amincoding/winscript/main/install-script.ps1 | iex
# =============================================================================

$ErrorActionPreference = "SilentlyContinue"

function Write-Header($text) { Write-Host ""; Write-Host ("=" * 60) -ForegroundColor Cyan; Write-Host "  $text" -ForegroundColor Yellow; Write-Host ("=" * 60) -ForegroundColor Cyan }
function Write-Step($text)   { Write-Host "  >> $text" -ForegroundColor Green }
function Write-Warn($text)   { Write-Host "  !! $text" -ForegroundColor Red }
function Write-Info($text)   { Write-Host "  -- $text" -ForegroundColor Gray }

# ── Require Administrator (all on one line to survive iex) ───────────────────
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) { Write-Warning "Not Administrator - relaunching elevated..."; Start-Process powershell "-ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/amincoding/winscript/main/install-script.ps1 | iex`"" -Verb RunAs; Exit }

# ── Detect Windows version ────────────────────────────────────────────────────
$OSVersion = [System.Environment]::OSVersion.Version
$OSMajor   = $OSVersion.Major
$OSMinor   = $OSVersion.Minor
$OSBuild   = $OSVersion.Build
$Is64bit   = [Environment]::Is64BitOperatingSystem

if     ($OSMajor -eq 10 -and $OSBuild -ge 22000) { $WinName = "Windows 11" }
elseif ($OSMajor -eq 10)                          { $WinName = "Windows 10" }
elseif ($OSMajor -eq 6  -and $OSMinor -eq 3)      { $WinName = "Windows 8.1" }
elseif ($OSMajor -eq 6  -and $OSMinor -eq 2)      { $WinName = "Windows 8" }
elseif ($OSMajor -eq 6  -and $OSMinor -eq 1)      { $WinName = "Windows 7" }
else                                               { $WinName = "Unknown Windows" }

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
if ($Is64bit) { Write-Host "  Arch     : 64-bit" -ForegroundColor Magenta } else { Write-Host "  Arch     : 32-bit" -ForegroundColor Magenta }
Write-Host ""
Start-Sleep -Seconds 2

# =============================================================================
# 1. TASKBAR SMALL ICONS
# =============================================================================
Write-Header "1. Setting Taskbar to Small Icons"

$AdvKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (!(Test-Path $AdvKey)) { New-Item -Path $AdvKey -Force | Out-Null }
Set-ItemProperty -Path $AdvKey -Name "TaskbarSmallIcons" -Value 1 -Type DWord -Force
Write-Step "TaskbarSmallIcons = 1"

if ($OSBuild -ge 22000) {
    Set-ItemProperty -Path $AdvKey -Name "TaskbarSi" -Value 0 -Type DWord -Force
    Write-Step "Win11 TaskbarSi = 0 (small)"
}

# =============================================================================
# 2. DESKTOP ICONS
# =============================================================================
Write-Header "2. Showing This PC and User Folder on Desktop"

$ThisPC_GUID     = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
$UserFolder_GUID = "{59031a47-3f72-44a7-89c5-5595fe6b30ee}"
$IconKey1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
$IconKey2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu"

foreach ($key in @($IconKey1, $IconKey2)) {
    if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name $ThisPC_GUID     -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $key -Name $UserFolder_GUID -Value 0 -Type DWord -Force
}
Write-Step "This PC icon: visible"
Write-Step "User Folder icon: visible"

# =============================================================================
# 3. POWER SETTINGS
# =============================================================================
Write-Header "3. Power Button / Sleep Button / Lid"

powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
Write-Step "Power button -> Shutdown"

powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 1
Write-Step "Sleep button -> Sleep"

powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
Write-Step "Lid close -> Do nothing"

powercfg -SetActive SCHEME_CURRENT
Write-Step "Power scheme applied"

# =============================================================================
# 4. .NET FRAMEWORK 3.5
# =============================================================================
Write-Header "4. Enabling .NET Framework 3.5"

$net35 = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue
if ($net35 -and $net35.State -eq "Enabled") {
    Write-Step ".NET 3.5 already enabled"
} else {
    Write-Step "Enabling .NET 3.5 via DISM..."
    DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Step ".NET 3.5 enabled successfully" } else { Write-Warn ".NET 3.5 failed — enable manually via Windows Features" }
}

# =============================================================================
# 5. WINDOWS UPDATE
# =============================================================================
Write-Header "5. Running Windows Update"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Step "Setting up PSWindowsUpdate..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) { Install-Module PSWindowsUpdate -Force -Scope CurrentUser -Confirm:$false | Out-Null }
    Import-Module PSWindowsUpdate -Force -ErrorAction Stop
    Write-Step "Searching and installing updates..."
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction SilentlyContinue
    Write-Step "Windows Update done"
} catch {
    Write-Warn "PSWindowsUpdate failed — triggering via wuauclt..."
    Start-Process wuauclt -ArgumentList "/detectnow /updatenow" -ErrorAction SilentlyContinue
    Write-Step "Windows Update triggered via wuauclt"
}

# =============================================================================
# 6. WINGET SETUP
# =============================================================================
Write-Header "6. Checking Winget"

function Get-WingetExe {
    $c1 = Get-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue
    if ($c1) { return $c1.FullName }
    $c2 = Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c2) { return $c2.FullName }
    $c3 = Get-Command winget -ErrorAction SilentlyContinue
    if ($c3) { return $c3.Source }
    return $null
}

$WingetExe = Get-WingetExe

if (-not $WingetExe) {
    Write-Step "Winget not found — installing from GitHub..."
    try {
        $rel  = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $msix = $rel.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        $instPath = "$env:TEMP\winget.msixbundle"
        (New-Object System.Net.WebClient).DownloadFile($msix.browser_download_url, $instPath)
        Add-AppxPackage -Path $instPath -ErrorAction Stop
        Start-Sleep -Seconds 5
        $WingetExe = Get-WingetExe
        if ($WingetExe) { Write-Step "Winget installed: $WingetExe" } else { Write-Warn "Winget install done but exe not found" }
    } catch { Write-Warn "Winget install failed: $_" }
} else {
    Write-Step "Winget found: $WingetExe"
    & $WingetExe source update --disable-interactivity 2>&1 | Out-Null
    Write-Step "Winget sources updated"
}

function Install-App {
    param([string]$AppName, [string]$WingetID)
    if (-not $WingetExe) { Write-Warn "Winget unavailable — skipping $AppName"; return }
    Write-Step "Installing $AppName..."
    & $WingetExe install --id $WingetID --exact --scope machine --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        Write-Host "     [OK] $AppName" -ForegroundColor Green
    } else {
        Write-Host "     [!!] $AppName failed (exit code $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

# =============================================================================
# 7. INSTALL APPS
# =============================================================================
Write-Header "7. Installing Applications"

Install-App "WinRAR"        "RARLab.WinRAR"
Install-App "AnyDesk"       "AnyDeskSoftwareGmbH.AnyDesk"
Install-App "VLC Player"    "VideoLAN.VLC"
Install-App "Foxit Reader"  "Foxit.FoxitReader"
Install-App "Google Chrome" "Google.Chrome"

Write-Step "Installing DirectX End-User Runtime..."
$dxPath = "$env:TEMP\dxwebsetup.exe"
try {
    (New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe", $dxPath)
    Start-Process -FilePath $dxPath -ArgumentList "/silent" -Wait -ErrorAction Stop
    Write-Host "     [OK] DirectX" -ForegroundColor Green
} catch { Write-Warn "DirectX failed: $_" }

# =============================================================================
# 7b. OFFICE 365 - 64-bit - EN / AR / FR
# =============================================================================
Write-Header "7b. Installing Office 365 (64-bit | EN + AR + FR)"

$odtDir   = "$env:TEMP\ODT"
$odtExe   = "$odtDir\ODTsetup.exe"
$odtSetup = "$odtDir\setup.exe"
$xmlPath  = "$odtDir\office365.xml"
$odtUrl   = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17531-20046.exe"

New-Item -ItemType Directory -Path $odtDir -Force | Out-Null

try {
    Write-Step "Downloading Office Deployment Tool..."
    (New-Object System.Net.WebClient).DownloadFile($odtUrl, $odtExe)

    Write-Step "Extracting ODT..."
    Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:`"$odtDir`"" -Wait -ErrorAction Stop

    if (-not (Test-Path $odtSetup)) { throw "setup.exe not found after ODT extraction" }

    Write-Step "Writing Office config (64-bit, EN+AR+FR)..."
    $officeXml  = '<?xml version="1.0" encoding="utf-8"?>'
    $officeXml += '<Configuration ID="winsetup-office365">'
    $officeXml += '  <Add OfficeClientEdition="64" Channel="Current" MigrateArch="TRUE">'
    $officeXml += '    <Product ID="O365ProPlusRetail">'
    $officeXml += '      <Language ID="en-us" />'
    $officeXml += '      <Language ID="ar-sa" />'
    $officeXml += '      <Language ID="fr-fr" />'
    $officeXml += '      <ExcludeApp ID="Access" />'
    $officeXml += '      <ExcludeApp ID="Groove" />'
    $officeXml += '      <ExcludeApp ID="Lync" />'
    $officeXml += '      <ExcludeApp ID="Publisher" />'
    $officeXml += '    </Product>'
    $officeXml += '  </Add>'
    $officeXml += '  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />'
    $officeXml += '  <Updates Enabled="TRUE" Channel="Current" />'
    $officeXml += '  <RemoveMSI />'
    $officeXml += '  <Display Level="Full" AcceptEULA="TRUE" />'
    $officeXml += '  <Logging Level="Standard" Path="%temp%\OfficeSetupLog" />'
    $officeXml += '</Configuration>'
    $officeXml | Out-File -FilePath $xmlPath -Encoding UTF8 -Force

    Write-Step "Starting Office 365 install (this takes several minutes)..."
    $proc = Start-Process -FilePath $odtSetup -ArgumentList "/configure `"$xmlPath`"" -Wait -PassThru -ErrorAction Stop

    if ($proc.ExitCode -eq 0) { Write-Host "     [OK] Office 365 installed" -ForegroundColor Green } else { Write-Warn "Office exited with code $($proc.ExitCode) — check %temp%\OfficeSetupLog" }
} catch { Write-Warn "Office 365 failed: $_" }

# =============================================================================
# 8. WALLPAPER
# =============================================================================
Write-Header "8. Setting Desktop Wallpaper"

$WallpaperURL  = "https://raw.githubusercontent.com/amincoding/winscript/main/Gemini_Generated_Image_wrbxznwrbxznwrbx.png"
$WallpaperPath = "$env:PUBLIC\WinSetupWallpaper.png"

try {
    Write-Step "Downloading wallpaper from GitHub..."
    (New-Object System.Net.WebClient).DownloadFile($WallpaperURL, $WallpaperPath)

    if (-not (Test-Path $WallpaperPath) -or (Get-Item $WallpaperPath).Length -lt 1000) { throw "File missing or too small — download failed" }
    Write-Step "Downloaded OK: $('{0:N0}' -f (Get-Item $WallpaperPath).Length) bytes"

    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper"      -Value $WallpaperPath -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper"  -Value "0"  -Force

    $wallpaperCode = 'using System; using System.Runtime.InteropServices; public class WinWallpaper { [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern bool SystemParametersInfo(uint a, uint b, string c, uint d); public static void Set(string p) { SystemParametersInfo(0x0014,0,p,0x0003); } }'
    Add-Type -TypeDefinition $wallpaperCode -ErrorAction SilentlyContinue
    [WinWallpaper]::Set($WallpaperPath)
    Write-Step "Wallpaper applied successfully"
} catch { Write-Warn "Wallpaper failed: $_" }

# =============================================================================
# 9. RESTART EXPLORER
# =============================================================================
Write-Header "9. Restarting Explorer"

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process explorer
Write-Step "Explorer restarted — all UI changes applied"

# =============================================================================
# 10. ACTIVATION
# =============================================================================
Write-Header "10. Activation"

Write-Host "  Press ENTER to run activation, or Ctrl+C to skip..." -ForegroundColor Yellow
Read-Host

try { Invoke-RestMethod https://get.activated.win | Invoke-Expression } catch { Write-Warn "Activation error: $_" }

# =============================================================================
# DONE
# =============================================================================
Write-Header "All Done!"
Write-Host ""
Write-Host "  [+] Taskbar small icons"                           -ForegroundColor Green
Write-Host "  [+] This PC + User Folder on desktop"              -ForegroundColor Green
Write-Host "  [+] Power / Sleep / Lid configured"                -ForegroundColor Green
Write-Host "  [+] .NET 3.5 enabled"                              -ForegroundColor Green
Write-Host "  [+] Windows Update run"                            -ForegroundColor Green
Write-Host "  [+] WinRAR, AnyDesk, VLC, Foxit, Chrome, DirectX" -ForegroundColor Green
Write-Host "  [+] Office 365 64-bit (EN + AR + FR)"              -ForegroundColor Green
Write-Host "  [+] Wallpaper set"                                 -ForegroundColor Green
Write-Host "  [+] Activation run"                                -ForegroundColor Green
Write-Host ""
Write-Host "  Reboot recommended to finalize all changes." -ForegroundColor Yellow
Write-Host ""

$reboot = Read-Host "  Reboot now? (Y/N)"
if ($reboot -match "^[Yy]") { Restart-Computer -Force }
