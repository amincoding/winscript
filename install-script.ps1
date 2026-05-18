# =============================================================================
#  install-script.ps1 - Universal Windows Setup Script
#  Supports: Windows 7, 8, 8.1, 10, 11
#  Run: irm https://raw.githubusercontent.com/amincoding/winscript/main/install-script.ps1 | iex
# =============================================================================

$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# HELPERS
# =============================================================================

function Write-Header($text) {
    Write-Host ""
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Yellow
    Write-Host ("=" * 65) -ForegroundColor Cyan
}
function Write-Step($text) { Write-Host "  >> $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "  !! $text" -ForegroundColor Red }
function Write-Info($text) { Write-Host "  -- $text" -ForegroundColor Gray }
function Write-Ok($text)   { Write-Host "     [OK] $text" -ForegroundColor Green }
function Write-Fail($text) { Write-Host "     [!!] $text" -ForegroundColor Yellow }

# ── Progress bar ──────────────────────────────────────────────────────────────
$script:ProgressTotal   = 1
$script:ProgressCurrent = 0
$script:ProgressLabel   = ""

function Set-ProgressTotal($n) { $script:ProgressTotal = $n; $script:ProgressCurrent = 0 }

function Step-Progress($label) {
    $script:ProgressCurrent++
    $script:ProgressLabel = $label
    $pct = [int](($script:ProgressCurrent / $script:ProgressTotal) * 100)
    Write-Progress -Activity "WinSetup" -Status "  Step $($script:ProgressCurrent)/$($script:ProgressTotal): $label" -PercentComplete $pct
    Write-Header "$($script:ProgressCurrent)/$($script:ProgressTotal) — $label"
}

function Done-Progress {
    Write-Progress -Activity "WinSetup" -Completed
}

# ── Require Administrator ─────────────────────────────────────────────────────
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Warning "Not Administrator - relaunching elevated..."
    Start-Process powershell "-ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/amincoding/winscript/main/install-script.ps1 | iex`"" -Verb RunAs
    Exit
}

# ── Detect Windows version ────────────────────────────────────────────────────
$OSVersion = [System.Environment]::OSVersion.Version
$OSMajor   = $OSVersion.Major
$OSMinor   = $OSVersion.Minor
$OSBuild   = $OSVersion.Build
$Is64bit   = [Environment]::Is64BitOperatingSystem

if     ($OSMajor -eq 10 -and $OSBuild -ge 22000) { $WinName = "Windows 11" }
elseif ($OSMajor -eq 10)                          { $WinName = "Windows 10" }
elseif ($OSMajor -eq 6 -and $OSMinor -eq 3)       { $WinName = "Windows 8.1" }
elseif ($OSMajor -eq 6 -and $OSMinor -eq 2)       { $WinName = "Windows 8" }
elseif ($OSMajor -eq 6 -and $OSMinor -eq 1)       { $WinName = "Windows 7" }
else                                               { $WinName = "Unknown Windows" }

# =============================================================================
# BANNER
# =============================================================================
Clear-Host
Write-Host ""
Write-Host "  ██╗    ██╗██╗███╗   ██╗███████╗███████╗████████╗██╗   ██╗██████╗ " -ForegroundColor Cyan
Write-Host "  ██║    ██║██║████╗  ██║██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗" -ForegroundColor Cyan
Write-Host "  ██║ █╗ ██║██║██╔██╗ ██║███████╗█████╗     ██║   ██║   ██║██████╔╝" -ForegroundColor Cyan
Write-Host "  ██║███╗██║██║██║╚██╗██║╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ " -ForegroundColor Cyan
Write-Host "  ╚███╔███╔╝██║██║ ╚████║███████║███████╗   ██║   ╚██████╔╝██║     " -ForegroundColor Cyan
Write-Host "   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝    " -ForegroundColor Cyan
Write-Host ""
Write-Host "  OS   : $WinName (Build $OSBuild)" -ForegroundColor Magenta
if ($Is64bit) { Write-Host "  Arch : 64-bit" -ForegroundColor Magenta } else { Write-Host "  Arch : 32-bit" -ForegroundColor Magenta }
Write-Host ""

# =============================================================================
# INTERACTIVE SELECTION MENU
# =============================================================================

# Define all tasks
$tasks = [ordered]@{
    "Taskbar"    = "Set taskbar to small icons"
    "Desktop"    = "Show This PC + User Folder on desktop"
    "Power"      = "Configure power / sleep / lid buttons"
    "DotNet"     = "Enable .NET Framework 3.5"
    "WinUpdate"  = "Run Windows Update"
    "WinRAR"     = "Install WinRAR"
    "AnyDesk"    = "Install AnyDesk"
    "VLC"        = "Install VLC Player"
    "Foxit"      = "Install Foxit Reader"
    "Chrome"     = "Install Google Chrome"
    "DirectX"    = "Install DirectX Runtime"
    "Office365"  = "Install Office 365 (64-bit, EN+AR+FR)"
    "Wallpaper"  = "Set desktop wallpaper"
    "Activation" = "Run activation script"
}

$selected = [ordered]@{}
foreach ($key in $tasks.Keys) { $selected[$key] = $true }   # all ON by default

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║              WINSETUP — SELECT TASKS TO RUN                 ║" -ForegroundColor Cyan
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  SPACE = toggle   A = all   N = none   ENTER = start        ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $i = 0
    foreach ($key in $tasks.Keys) {
        $i++
        $check = if ($selected[$key]) { "[X]" } else { "[ ]" }
        $color = if ($selected[$key]) { "Green" } else { "DarkGray" }
        Write-Host ("  {0,2}. {1} {2}" -f $i, $check, $tasks[$key]) -ForegroundColor $color
    }
    Write-Host ""
    Write-Host "  Enter number to toggle, A=all, N=none, ENTER to start: " -ForegroundColor Yellow -NoNewline
}

# ── Menu loop ─────────────────────────────────────────────────────────────────
while ($true) {
    Show-Menu
    $input = Read-Host

    if ($input -eq "") { break }   # ENTER = start

    if ($input -match "^[Aa]$") {
        foreach ($key in $tasks.Keys) { $selected[$key] = $true }
        continue
    }
    if ($input -match "^[Nn]$") {
        foreach ($key in $tasks.Keys) { $selected[$key] = $false }
        continue
    }
    if ($input -match "^\d+$") {
        $num = [int]$input
        if ($num -ge 1 -and $num -le $tasks.Count) {
            $key = @($tasks.Keys)[$num - 1]
            $selected[$key] = -not $selected[$key]
        }
        continue
    }
}

# Count how many steps are selected
$totalSteps = ($selected.Values | Where-Object { $_ -eq $true }).Count
if ($totalSteps -eq 0) { Write-Warn "No tasks selected. Exiting."; Exit }
Set-ProgressTotal $totalSteps

Write-Host ""
Write-Host "  Starting setup with $totalSteps task(s) selected..." -ForegroundColor Cyan
Start-Sleep -Seconds 1

# =============================================================================
# WINGET — Install if missing (always needed, done before tasks)
# =============================================================================

$needsWinget = $selected["WinRAR"] -or $selected["AnyDesk"] -or $selected["VLC"] -or $selected["Foxit"] -or $selected["Chrome"]

function Get-WingetExe {
    $c1 = Get-Item "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue
    if ($c1) { return $c1.FullName }
    $c2 = Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c2) { return $c2.FullName }
    $c3 = Get-Command winget -ErrorAction SilentlyContinue
    if ($c3) { return $c3.Source }
    return $null
}

$WingetExe = $null

if ($needsWinget) {
    Write-Progress -Activity "WinSetup" -Status "  Checking Winget..." -PercentComplete 0
    $WingetExe = Get-WingetExe

    if (-not $WingetExe) {
        Write-Host ""
        Write-Host "  >> Winget not found — downloading and installing..." -ForegroundColor Green

        # Step 1: Try via MSIX from GitHub releases
        try {
            Write-Host "  -- Fetching latest winget release from GitHub..." -ForegroundColor Gray
            $rel  = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -ErrorAction Stop
            $msix = $rel.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1

            if ($msix) {
                $instPath = "$env:TEMP\winget.msixbundle"
                Write-Host "  -- Downloading $($msix.name)..." -ForegroundColor Gray
                Write-Progress -Activity "WinSetup" -Status "  Downloading Winget..." -PercentComplete 2

                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($msix.browser_download_url, $instPath)

                # Also download dependencies (VCLibs + UIXaml)
                Write-Host "  -- Downloading VCLibs dependency..." -ForegroundColor Gray
                $vclibsUrl  = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
                $vclibsPath = "$env:TEMP\VCLibs.appx"
                $wc.DownloadFile($vclibsUrl, $vclibsPath)

                Write-Host "  -- Installing dependencies..." -ForegroundColor Gray
                Add-AppxPackage -Path $vclibsPath -ErrorAction SilentlyContinue

                Write-Host "  -- Installing Winget..." -ForegroundColor Gray
                Add-AppxPackage -Path $instPath -ErrorAction Stop
                Start-Sleep -Seconds 5
                $WingetExe = Get-WingetExe
            }
        } catch {
            Write-Host "  !! GitHub install failed: $_" -ForegroundColor Red
        }

        # Step 2: Fallback — try winget-install script
        if (-not $WingetExe) {
            Write-Host "  -- Trying fallback winget installer..." -ForegroundColor Gray
            try {
                $fallbackScript = Invoke-RestMethod "https://raw.githubusercontent.com/asheroto/winget-install/master/winget-install.ps1" -ErrorAction Stop
                $fallbackScript | Invoke-Expression
                Start-Sleep -Seconds 5
                $WingetExe = Get-WingetExe
            } catch {
                Write-Host "  !! Fallback also failed: $_" -ForegroundColor Red
            }
        }

        if ($WingetExe) {
            Write-Ok "Winget installed: $WingetExe"
        } else {
            Write-Warn "Winget could not be installed. App installs will be skipped."
        }
    } else {
        Write-Host "  >> Winget found: $WingetExe" -ForegroundColor Green
        & $WingetExe source update --disable-interactivity 2>&1 | Out-Null
        Write-Host "  >> Winget sources updated" -ForegroundColor Green
    }
}

# ── App installer with 4-layer retry ─────────────────────────────────────────
function Install-App {
    param([string]$AppName, [string]$WingetID, [switch]$NoScope)
    if (-not $WingetExe) { Write-Warn "Winget unavailable — skipping $AppName"; return }

    Write-Step "Installing $AppName..."

    # Attempt 1
    if ($NoScope) {
        & $WingetExe install --id $WingetID --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    } else {
        & $WingetExe install --id $WingetID --exact --scope machine --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    }

    # Attempt 2: scope not supported
    if ($LASTEXITCODE -eq -1978335212) {
        Write-Info "Scope machine not supported — retrying without scope..."
        & $WingetExe install --id $WingetID --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    }

    # Attempt 3: network error — wait and retry
    if ($LASTEXITCODE -eq -2147012867) {
        Write-Info "Network error — waiting 5s and retrying..."
        Start-Sleep -Seconds 5
        & $WingetExe install --id $WingetID --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    }

    # Attempt 4: drop --exact
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        Write-Info "Retrying without --exact..."
        & $WingetExe install --id $WingetID --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    }

    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        Write-Ok $AppName
    } else {
        Write-Fail "$AppName (exit code $LASTEXITCODE)"
    }
}

# =============================================================================
# EXECUTE SELECTED TASKS
# =============================================================================

# ── 1. Taskbar ────────────────────────────────────────────────────────────────
if ($selected["Taskbar"]) {
    Step-Progress "Setting Taskbar to Small Icons"
    $AdvKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (!(Test-Path $AdvKey)) { New-Item -Path $AdvKey -Force | Out-Null }
    Set-ItemProperty -Path $AdvKey -Name "TaskbarSmallIcons" -Value 1 -Type DWord -Force
    Write-Step "TaskbarSmallIcons = 1"
    if ($OSBuild -ge 22000) {
        Set-ItemProperty -Path $AdvKey -Name "TaskbarSi" -Value 0 -Type DWord -Force
        Write-Step "Win11 TaskbarSi = 0 (small)"
    }
    Write-Ok "Taskbar set to small icons"
}

# ── 2. Desktop Icons ──────────────────────────────────────────────────────────
if ($selected["Desktop"]) {
    Step-Progress "Showing This PC and User Folder on Desktop"
    $ThisPC_GUID     = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
    $UserFolder_GUID = "{59031a47-3f72-44a7-89c5-5595fe6b30ee}"
    $IconKey1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    $IconKey2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu"
    foreach ($key in @($IconKey1, $IconKey2)) {
        if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        Set-ItemProperty -Path $key -Name $ThisPC_GUID     -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $key -Name $UserFolder_GUID -Value 0 -Type DWord -Force
    }
    Write-Ok "This PC and User Folder icons visible"
}

# ── 3. Power Settings ─────────────────────────────────────────────────────────
if ($selected["Power"]) {
    Step-Progress "Configuring Power / Sleep / Lid"
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
    Write-Ok "Power scheme applied"
}

# ── 4. .NET 3.5 ───────────────────────────────────────────────────────────────
if ($selected["DotNet"]) {
    Step-Progress "Enabling .NET Framework 3.5"
    $net35 = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue
    if ($net35 -and $net35.State -eq "Enabled") {
        Write-Ok ".NET 3.5 already enabled"
    } else {
        Write-Step "Enabling via DISM..."
        DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok ".NET 3.5 enabled" } else { Write-Fail ".NET 3.5 — enable manually via Windows Features" }
    }
}

# ── 5. Windows Update ─────────────────────────────────────────────────────────
if ($selected["WinUpdate"]) {
    Step-Progress "Running Windows Update"
    try {
        Write-Step "Installing PSWindowsUpdate module..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) { Install-Module PSWindowsUpdate -Force -Scope CurrentUser -Confirm:$false | Out-Null }
        Import-Module PSWindowsUpdate -Force -ErrorAction Stop
        Write-Step "Searching and installing updates (this may take a while)..."
        Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction SilentlyContinue
        Write-Ok "Windows Update completed"
    } catch {
        Write-Warn "PSWindowsUpdate failed — triggering via wuauclt..."
        Start-Process wuauclt -ArgumentList "/detectnow /updatenow" -ErrorAction SilentlyContinue
        Write-Step "Windows Update triggered via wuauclt (running in background)"
    }
}

# ── 6. WinRAR ─────────────────────────────────────────────────────────────────
if ($selected["WinRAR"]) {
    Step-Progress "Installing WinRAR"
    Install-App "WinRAR" "RARLab.WinRAR"
}

# ── 7. AnyDesk ────────────────────────────────────────────────────────────────
if ($selected["AnyDesk"]) {
    Step-Progress "Installing AnyDesk"
    Install-App "AnyDesk" "AnyDeskSoftwareGmbH.AnyDesk" -NoScope
}

# ── 8. VLC ────────────────────────────────────────────────────────────────────
if ($selected["VLC"]) {
    Step-Progress "Installing VLC Player"
    Install-App "VLC Player" "VideoLAN.VLC"
}

# ── 9. Foxit Reader ───────────────────────────────────────────────────────────
if ($selected["Foxit"]) {
    Step-Progress "Installing Foxit Reader"
    Install-App "Foxit Reader" "Foxit.FoxitReader"
}

# ── 10. Google Chrome ─────────────────────────────────────────────────────────
if ($selected["Chrome"]) {
    Step-Progress "Installing Google Chrome"
    Install-App "Google Chrome" "Google.Chrome"
}

# ── 11. DirectX ───────────────────────────────────────────────────────────────
if ($selected["DirectX"]) {
    Step-Progress "Installing DirectX Runtime"
    $dxPath = "$env:TEMP\dxwebsetup.exe"
    try {
        Write-Step "Downloading DirectX installer..."
        (New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe", $dxPath)
        Start-Process -FilePath $dxPath -ArgumentList "/silent" -Wait -ErrorAction Stop
        Write-Ok "DirectX installed"
    } catch { Write-Fail "DirectX: $_" }
}

# ── 12. Office 365 ────────────────────────────────────────────────────────────
if ($selected["Office365"]) {
    Step-Progress "Installing Office 365 (64-bit | EN + AR + FR)"

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

        Write-Step "Writing Office XML config..."
        $officeXml  = '<?xml version="1.0" encoding="utf-8"?>'
        $officeXml += '<Configuration ID="winsetup-office365">'
        $officeXml += '<Add OfficeClientEdition="64" Channel="Current" MigrateArch="TRUE">'
        $officeXml += '<Product ID="O365ProPlusRetail">'
        $officeXml += '<Language ID="en-us" />'
        $officeXml += '<Language ID="ar-sa" />'
        $officeXml += '<Language ID="fr-fr" />'
        $officeXml += '<ExcludeApp ID="Access" />'
        $officeXml += '<ExcludeApp ID="Groove" />'
        $officeXml += '<ExcludeApp ID="Lync" />'
        $officeXml += '<ExcludeApp ID="Publisher" />'
        $officeXml += '</Product>'
        $officeXml += '</Add>'
        $officeXml += '<Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />'
        $officeXml += '<Updates Enabled="TRUE" Channel="Current" />'
        $officeXml += '<RemoveMSI />'
        $officeXml += '<Display Level="Full" AcceptEULA="TRUE" />'
        $officeXml += '<Logging Level="Standard" Path="%temp%\OfficeSetupLog" />'
        $officeXml += '</Configuration>'
        $officeXml | Out-File -FilePath $xmlPath -Encoding UTF8 -Force

        Write-Step "Downloading and installing Office 365 (this takes several minutes)..."
        $proc = Start-Process -FilePath $odtSetup -ArgumentList "/configure `"$xmlPath`"" -Wait -PassThru -ErrorAction Stop

        if ($proc.ExitCode -eq 0) { Write-Ok "Office 365 installed successfully" } else { Write-Fail "Office exited with code $($proc.ExitCode) — check %temp%\OfficeSetupLog" }
    } catch { Write-Fail "Office 365: $_" }
}

# ── 13. Wallpaper ─────────────────────────────────────────────────────────────
if ($selected["Wallpaper"]) {
    Step-Progress "Setting Desktop Wallpaper"
    $WallpaperURL  = "https://raw.githubusercontent.com/amincoding/winscript/main/Gemini_Generated_Image_wrbxznwrbxznwrbx.png"
    $WallpaperPath = "$env:PUBLIC\WinSetupWallpaper.png"
    try {
        Write-Step "Downloading wallpaper from GitHub..."
        (New-Object System.Net.WebClient).DownloadFile($WallpaperURL, $WallpaperPath)
        if (-not (Test-Path $WallpaperPath) -or (Get-Item $WallpaperPath).Length -lt 1000) { throw "File missing or too small" }
        Write-Step "Downloaded: $('{0:N0}' -f (Get-Item $WallpaperPath).Length) bytes"

        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper"      -Value $WallpaperPath -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper"  -Value "0"  -Force

        $wallpaperCode = 'using System; using System.Runtime.InteropServices; public class WinWallpaper { [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern bool SystemParametersInfo(uint a, uint b, string c, uint d); public static void Set(string p) { SystemParametersInfo(0x0014,0,p,0x0003); } }'
        Add-Type -TypeDefinition $wallpaperCode -ErrorAction SilentlyContinue
        [WinWallpaper]::Set($WallpaperPath)
        Write-Ok "Wallpaper applied"
    } catch { Write-Fail "Wallpaper: $_" }
}

# ── Restart Explorer to apply UI changes ──────────────────────────────────────
if ($selected["Taskbar"] -or $selected["Desktop"] -or $selected["Wallpaper"]) {
    Write-Host ""
    Write-Step "Restarting Explorer to apply UI changes..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Process explorer
    Write-Ok "Explorer restarted"
}

# ── 14. Activation ────────────────────────────────────────────────────────────
if ($selected["Activation"]) {
    Step-Progress "Activation"
    Write-Host "  Press ENTER to run activation, or Ctrl+C to skip..." -ForegroundColor Yellow
    Read-Host
    try { Invoke-RestMethod https://get.activated.win | Invoke-Expression } catch { Write-Fail "Activation: $_" }
}

# =============================================================================
# DONE
# =============================================================================
Done-Progress

Write-Host ""
Write-Host ("=" * 65) -ForegroundColor Cyan
Write-Host "  ALL DONE!" -ForegroundColor Yellow
Write-Host ("=" * 65) -ForegroundColor Cyan
Write-Host ""

foreach ($key in $tasks.Keys) {
    if ($selected[$key]) {
        Write-Host "  [+] $($tasks[$key])" -ForegroundColor Green
    } else {
        Write-Host "  [-] $($tasks[$key]) (skipped)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "  A reboot is recommended to finalize all changes." -ForegroundColor Yellow
Write-Host ""
$reboot = Read-Host "  Reboot now? (Y/N)"
if ($reboot -match "^[Yy]") { Restart-Computer -Force }
