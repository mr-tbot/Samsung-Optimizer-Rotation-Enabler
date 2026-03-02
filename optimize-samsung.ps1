# Samsung Device Optimizer v2.0 — PowerShell Edition
# Interactive tool that detects your Samsung device and offers tailored optimizations via ADB.
#
# Usage:
#   .\optimize-samsung.ps1                   # Interactive mode
#   .\optimize-samsung.ps1 -All              # Apply all optimizations
#   .\optimize-samsung.ps1 -DryRun           # Preview without changes
#   .\optimize-samsung.ps1 -Revert           # Undo all changes
#   .\optimize-samsung.ps1 -Report           # Show device status only
#   .\optimize-samsung.ps1 -InstallAdb       # Download and install ADB

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$DryRun,
    [switch]$Revert,
    [switch]$Report,
    [switch]$Rotation,
    [switch]$Battery,
    [switch]$Memory,
    [switch]$Bloatware,
    [switch]$PerApp,
    [switch]$Updates,
    [switch]$Dns,
    [switch]$InstallAdb,
    [string]$Serial = "",
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$script:ADB = ""
$script:SERIAL = $Serial
$script:DRY_RUN = $DryRun.IsPresent
$script:REVERT = $Revert.IsPresent

# Device info
$script:DEVICE_MODEL = ""
$script:DEVICE_NAME = ""
$script:DEVICE_TYPE = ""
$script:ANDROID_VER = ""
$script:SDK_VER = ""
$script:RAM_GB = 0
$script:RAM_TOTAL_KB = 0

# ─── Bloatware packages ─────────────────────────────────────────────────────

$script:BLOATWARE_PACKAGES = @(
    "com.samsung.android.bixby.agent",
    "com.samsung.android.bixby.wakeup",
    "com.samsung.android.bixbyvision.framework",
    "com.samsung.android.app.spage",
    "com.samsung.android.arzone",
    "com.samsung.android.visionintelligence",
    "com.samsung.android.game.gos",
    "com.samsung.android.game.gametools",
    "com.samsung.android.app.tips",
    "com.samsung.android.smartsuggestions",
    "com.samsung.android.rubin.app",
    "com.samsung.android.mdecservice",
    "com.google.android.adservices.api",
    "com.google.mainline.adservices",
    "com.google.android.apps.turbo"
)

# ─── Helper Functions ────────────────────────────────────────────────────────

function Write-Info    { param($msg) Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host $msg }
function Write-Ok      { param($msg) Write-Host "[OK]   " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn    { param($msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Fail    { param($msg) Write-Host "[FAIL] " -ForegroundColor Red -NoNewline; Write-Host $msg }
function Write-Header  {
    param($msg)
    Write-Host ""
    Write-Host ("=" * 50) -ForegroundColor Blue
    Write-Host " $msg" -ForegroundColor Blue
    Write-Host ("=" * 50) -ForegroundColor Blue
}

function Invoke-Adb {
    param([string[]]$Arguments)
    if ($script:DRY_RUN) {
        Write-Host "[DRY-RUN] " -ForegroundColor Yellow -NoNewline
        Write-Host "adb -s $($script:SERIAL) shell $($Arguments -join ' ')"
        return ""
    }
    $result = & $script:ADB -s $script:SERIAL shell @Arguments 2>&1
    return ($result -join "`n").Trim()
}

# ─── ADB Installation ────────────────────────────────────────────────────────

function Find-Adb {
    # Check PATH first
    $adbPath = Get-Command "adb" -ErrorAction SilentlyContinue
    if ($adbPath) {
        $script:ADB = $adbPath.Source
        return $true
    }

    # Check common Windows locations
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:USERPROFILE\Android\Sdk\platform-tools\adb.exe",
        "$env:USERPROFILE\platform-tools\adb.exe",
        "C:\platform-tools\adb.exe",
        "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    )

    if ($env:ANDROID_HOME) {
        $candidates += "$env:ANDROID_HOME\platform-tools\adb.exe"
    }
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $script:ADB = $candidate
            return $true
        }
    }

    return $false
}

function Install-Adb {
    Write-Header "ADB INSTALLATION"
    Write-Host ""
    Write-Info "ADB (Android Debug Bridge) is required but was not found on your system."
    Write-Host ""
    Write-Host "  ADB is the official Android tool for communicating with devices over USB."
    Write-Host "  It will be downloaded from https://developer.android.com" -ForegroundColor Cyan
    Write-Host ""

    $url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    $installDir = "$env:USERPROFILE\platform-tools"
    $zipFile = "$env:TEMP\platform-tools.zip"

    Write-Host "  Download URL:  " -NoNewline; Write-Host $url -ForegroundColor White
    Write-Host "  Install to:    " -NoNewline; Write-Host $installDir -ForegroundColor White
    Write-Host ""

    $response = Read-Host "  Install ADB now? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($response)) { $response = "Y" }

    if ($response -notmatch "^[Yy]$") {
        Write-Host ""
        Write-Info "Skipped. Install ADB manually and re-run this script."
        Write-Host "  Download: $url"
        Write-Host "  Or: winget install Google.PlatformTools"
        exit 1
    }

    Write-Host ""

    # Download
    Write-Info "Downloading ADB platform-tools..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing
    }
    catch {
        Write-Fail "Download failed: $_"
        exit 1
    }

    $fileSize = [math]::Round((Get-Item $zipFile).Length / 1MB, 1)
    Write-Ok "Downloaded ${fileSize}MB"

    # Extract
    Write-Info "Extracting to $installDir..."
    if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
    try {
        Expand-Archive -Path $zipFile -DestinationPath $env:USERPROFILE -Force
        Remove-Item $zipFile -Force
    }
    catch {
        Write-Fail "Extraction failed: $_"
        exit 1
    }

    if (-not (Test-Path "$installDir\adb.exe")) {
        Write-Fail "adb.exe not found after extraction."
        exit 1
    }
    Write-Ok "Extracted successfully"

    # Add to PATH for this session
    $script:ADB = "$installDir\adb.exe"
    $env:PATH = "$installDir;$env:PATH"

    # Add to user PATH permanently
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*platform-tools*") {
        [Environment]::SetEnvironmentVariable("PATH", "$installDir;$currentPath", "User")
        Write-Ok "Added platform-tools to user PATH"
        Write-Info "Restart your terminal for PATH changes to take effect."
    }
    else {
        Write-Info "PATH entry already exists"
    }

    # Verify
    $version = & $script:ADB version 2>&1 | Select-Object -First 1
    Write-Host ""
    Write-Ok "ADB installed: $version"
    Write-Host ""
}

function Ensure-Adb {
    if (Find-Adb) { return }
    Install-Adb
}

# ─── Device Detection ────────────────────────────────────────────────────────

function Detect-Device {
    $rawDevices = & $script:ADB devices 2>&1
    $devices = $rawDevices | Where-Object { $_ -match "^\S+\s+device$" } | ForEach-Object { ($_ -split "\s+")[0] }

    if (-not $devices -or $devices.Count -eq 0) {
        Write-Host ""
        Write-Fail "No devices connected."
        Write-Host ""
        Write-Host "  Checklist:"
        Write-Host "    1. Device is connected via USB"
        Write-Host "    2. USB Debugging is enabled:"
        Write-Host "       Settings > Developer Options > USB Debugging"
        Write-Host "    3. You've accepted the 'Allow USB debugging?' prompt on the device"
        Write-Host ""
        Write-Host "  To enable Developer Options:"
        Write-Host "    Settings > About Phone > tap 'Build Number' 7 times"
        Write-Host ""
        exit 1
    }

    # Normalize to array
    if ($devices -is [string]) { $devices = @($devices) }

    if ($script:SERIAL) {
        if ($devices -notcontains $script:SERIAL) {
            Write-Fail "Device $($script:SERIAL) not found. Connected:"
            $devices | ForEach-Object { Write-Host "  $_" }
            exit 1
        }
    }
    elseif ($devices.Count -eq 1) {
        $script:SERIAL = $devices[0].Trim()
    }
    else {
        Write-Header "MULTIPLE DEVICES DETECTED"
        Write-Host ""

        for ($i = 0; $i -lt $devices.Count; $i++) {
            $s = $devices[$i].Trim()
            $model = (& $script:ADB -s $s shell getprop ro.product.model 2>&1).Trim()
            $name = (& $script:ADB -s $s shell settings get global device_name 2>&1).Trim()
            Write-Host "  $($i+1))  $model - $name  " -NoNewline
            Write-Host "[$s]" -ForegroundColor DarkGray
        }

        Write-Host ""
        $choice = Read-Host "  Select device [1-$($devices.Count)]"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }
        $idx = [int]$choice - 1

        if ($idx -lt 0 -or $idx -ge $devices.Count) {
            Write-Fail "Invalid selection."
            exit 1
        }

        $script:SERIAL = $devices[$idx].Trim()
    }

    # Populate device info
    $script:DEVICE_MODEL = (& $script:ADB -s $script:SERIAL shell getprop ro.product.model 2>&1).Trim()
    $script:DEVICE_NAME = (& $script:ADB -s $script:SERIAL shell settings get global device_name 2>&1).Trim()
    $script:ANDROID_VER = (& $script:ADB -s $script:SERIAL shell getprop ro.build.version.release 2>&1).Trim()
    $script:SDK_VER = (& $script:ADB -s $script:SERIAL shell getprop ro.build.version.sdk 2>&1).Trim()

    $meminfo = (& $script:ADB -s $script:SERIAL shell cat /proc/meminfo 2>&1) -join "`n"
    if ($meminfo -match "MemTotal:\s+(\d+)") {
        $script:RAM_TOTAL_KB = [int64]$Matches[1]
        $script:RAM_GB = [math]::Floor($script:RAM_TOTAL_KB / 1024 / 1024)
    }

    # Determine device type
    $modelLower = $script:DEVICE_MODEL.ToLower()
    $nameLower = $script:DEVICE_NAME.ToLower()
    $characteristics = (& $script:ADB -s $script:SERIAL shell getprop ro.build.characteristics 2>&1).Trim().ToLower()

    if ("$modelLower $nameLower" -match "fold|flip") {
        $script:DEVICE_TYPE = "foldable"
    }
    elseif ("$modelLower $nameLower $characteristics" -match "tab|tablet") {
        $script:DEVICE_TYPE = "tablet"
    }
    elseif ($script:DEVICE_MODEL -match "^SM-[PX]") {
        $script:DEVICE_TYPE = "tablet"
    }
    else {
        $script:DEVICE_TYPE = "phone"
    }
}

function Show-DeviceBanner {
    $typeLabel = switch ($script:DEVICE_TYPE) {
        "foldable" { "Foldable" }
        "tablet"   { "Tablet" }
        default    { "Phone" }
    }

    Write-Host ""
    Write-Host "  Connected Device" -ForegroundColor White
    Write-Host "  -------------------------------------------"
    Write-Host "  Model:    " -NoNewline -ForegroundColor White; Write-Host "$($script:DEVICE_MODEL) ($($script:DEVICE_NAME))"
    Write-Host "  Type:     " -NoNewline -ForegroundColor White; Write-Host $typeLabel
    Write-Host "  Android:  " -NoNewline -ForegroundColor White; Write-Host "$($script:ANDROID_VER) (SDK $($script:SDK_VER))"
    Write-Host "  RAM:      " -NoNewline -ForegroundColor White; Write-Host "$($script:RAM_GB)GB ($([math]::Floor($script:RAM_TOTAL_KB / 1024))MB)"
    Write-Host "  Serial:   " -NoNewline -ForegroundColor White; Write-Host $script:SERIAL -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Optimization Modules ────────────────────────────────────────────────────

function Apply-RotationFixes {
    Write-Header "ROTATION & DISPLAY FIXES"

    Write-Info "Enabling system auto-rotation..."
    Invoke-Adb "settings", "put", "system", "accelerometer_rotation", "1" | Out-Null
    Write-Ok "Auto-rotation enabled"

    Write-Info "Enabling rotation suggestions..."
    Invoke-Adb "settings", "put", "secure", "show_rotation_suggestions", "1" | Out-Null
    Write-Ok "Rotation suggestions enabled"

    Write-Info "Forcing all apps to follow sensor rotation..."
    Invoke-Adb "wm", "set-ignore-orientation-request", "true" | Out-Null
    Write-Ok "System-wide orientation override active"

    Write-Info "Enabling non-resizable multi-window support..."
    Invoke-Adb "settings", "put", "global", "enable_non_resizable_multi_window", "1" | Out-Null
    Write-Ok "Non-resizable multi-window enabled"

    if ($script:DEVICE_TYPE -eq "foldable") {
        Write-Info "Foldable detected - applying fold-specific settings..."

        Write-Info "Enabling flex mode panel..."
        Invoke-Adb "settings", "put", "global", "flex_mode_panel_enabled", "1" | Out-Null
        Write-Ok "Flex mode panel enabled"

        Write-Info "Enabling app continuity..."
        Invoke-Adb "settings", "put", "secure", "foldstar_settings_app_continuity_mode_setting", "1" | Out-Null
        Write-Ok "App continuity enabled"
    }

    Write-Info "Ensuring rotation icon is visible in status bar..."
    if (-not $script:DRY_RUN) {
        $blacklist = (& $script:ADB -s $script:SERIAL shell settings get secure icon_blacklist 2>&1).Trim()
        $newBlacklist = ($blacklist -replace "rotate,?", "") -replace "^,|,$", ""
        if ($newBlacklist -and $newBlacklist -ne "null") {
            Invoke-Adb "settings", "put", "secure", "icon_blacklist", $newBlacklist | Out-Null
        }
        else {
            Invoke-Adb "settings", "put", "secure", "icon_blacklist", '""' | Out-Null
        }
    }
    else {
        Write-Host "[DRY-RUN] " -ForegroundColor Yellow -NoNewline
        Write-Host "adb -s $($script:SERIAL) shell settings put secure icon_blacklist (cleaned)"
    }
    Write-Ok "Rotation icon visible in status bar"
}

function Revert-RotationFixes {
    Write-Header "REVERTING ROTATION & DISPLAY FIXES"

    Invoke-Adb "wm", "set-ignore-orientation-request", "false" | Out-Null
    Write-Ok "System-wide orientation override removed"

    if ($script:DEVICE_TYPE -eq "foldable") {
        Invoke-Adb "settings", "put", "global", "flex_mode_panel_enabled", "0" | Out-Null
        Invoke-Adb "settings", "put", "secure", "foldstar_settings_app_continuity_mode_setting", "0" | Out-Null
        Write-Ok "Fold-specific settings reverted"
    }
}

function Apply-BatteryFixes {
    Write-Header "BATTERY & POWER MANAGEMENT"

    Write-Info "Disabling app standby (prevents auto app sleeping)..."
    Invoke-Adb "settings", "put", "global", "app_standby_enabled", "0" | Out-Null
    Write-Ok "App standby disabled"

    Write-Info "Disabling battery tip app restrictions..."
    Invoke-Adb "settings", "put", "global", "battery_tip_constants", "app_restriction_enabled=false" | Out-Null
    Write-Ok "Battery tip restrictions disabled"

    Write-Info "Enabling WiFi scan throttle..."
    Invoke-Adb "settings", "put", "global", "wifi_scan_throttle_enabled", "1" | Out-Null
    Write-Ok "WiFi scan throttle enabled"
}

function Revert-BatteryFixes {
    Write-Header "REVERTING BATTERY & POWER MANAGEMENT"

    Invoke-Adb "settings", "put", "global", "app_standby_enabled", "1" | Out-Null
    Write-Ok "App standby re-enabled"

    Invoke-Adb "settings", "put", "global", "battery_tip_constants", "app_restriction_enabled=true" | Out-Null
    Write-Ok "Battery tip restrictions re-enabled"

    Invoke-Adb "settings", "put", "global", "wifi_scan_throttle_enabled", "0" | Out-Null
    Write-Ok "WiFi scan throttle disabled"
}

function Apply-MemoryFixes {
    Write-Header "MEMORY OPTIMIZATION"

    Write-Info "Device has ~$($script:RAM_GB)GB RAM"

    $currentRamPlus = (& $script:ADB -s $script:SERIAL shell settings get global ram_expand_size 2>&1).Trim()

    if ($script:RAM_GB -le 4 -and $currentRamPlus -ne "null" -and $currentRamPlus -ne "0") {
        Write-Info "Low RAM device with RAM Plus at ${currentRamPlus}MB - disabling to reduce swap thrashing..."
        Invoke-Adb "settings", "put", "global", "ram_expand_size", "0" | Out-Null
        Write-Ok "RAM Plus disabled (was ${currentRamPlus}MB)"
    }
    elseif ($currentRamPlus -ne "null" -and $currentRamPlus -ne "0") {
        Write-Info "RAM Plus is at ${currentRamPlus}MB - keeping as-is (sufficient RAM)"
    }
    else {
        Write-Info "RAM Plus already at 0 or not available"
    }
}

function Revert-MemoryFixes {
    Write-Header "REVERTING MEMORY OPTIMIZATION"
    if ($script:RAM_GB -le 4) {
        Invoke-Adb "settings", "put", "global", "ram_expand_size", "4096" | Out-Null
        Write-Ok "RAM Plus restored to 4GB"
    }
}

function Disable-Bloatware {
    Write-Header "BLOATWARE REMOVAL"

    $disabledCount = 0
    $skippedCount = 0
    $notFoundCount = 0

    $enabledPackages = (& $script:ADB -s $script:SERIAL shell pm list packages -e 2>&1) -join "`n"

    foreach ($pkg in $script:BLOATWARE_PACKAGES) {
        if ($enabledPackages -match [regex]::Escape($pkg)) {
            $result = Invoke-Adb "pm", "disable-user", "--user", "0", $pkg
            if ($result -match "new state: disabled") {
                Write-Ok "Disabled: $pkg"
                $disabledCount++
            }
            elseif ($result -match "DRY-RUN") {
                Write-Ok "Would disable: $pkg"
                $disabledCount++
            }
            else {
                Write-Warn "Could not disable: $pkg - $result"
                $skippedCount++
            }
        }
        else {
            $notFoundCount++
        }
    }

    # Bixby language packs
    Write-Info "Checking for Bixby on-device language packs..."
    $bixbyPacks = (& $script:ADB -s $script:SERIAL shell pm list packages -e 2>&1) |
        Where-Object { $_ -match "bixby\.ondevice" } |
        ForEach-Object { ($_ -replace "package:", "").Trim() }

    foreach ($pkg in $bixbyPacks) {
        $result = Invoke-Adb "pm", "disable-user", "--user", "0", $pkg
        if ($result -match "new state: disabled|DRY-RUN") {
            Write-Ok "Disabled: $pkg"
            $disabledCount++
        }
    }

    Write-Host ""
    Write-Info "Summary: $disabledCount disabled, $skippedCount skipped, $notFoundCount not installed"
}

function Enable-Bloatware {
    Write-Header "RE-ENABLING BLOATWARE"

    $disabledPackages = (& $script:ADB -s $script:SERIAL shell pm list packages -d 2>&1) -join "`n"

    foreach ($pkg in $script:BLOATWARE_PACKAGES) {
        if ($disabledPackages -match [regex]::Escape($pkg)) {
            $result = Invoke-Adb "pm", "enable", $pkg
            if ($result -match "new state") { Write-Ok "Re-enabled: $pkg" }
        }
    }

    $bixbyPacks = (& $script:ADB -s $script:SERIAL shell pm list packages -d 2>&1) |
        Where-Object { $_ -match "bixby\.ondevice" } |
        ForEach-Object { ($_ -replace "package:", "").Trim() }

    foreach ($pkg in $bixbyPacks) {
        $result = Invoke-Adb "pm", "enable", $pkg
        if ($result -match "new state") { Write-Ok "Re-enabled: $pkg" }
    }
}

function Apply-PerAppRotation {
    Write-Header "PER-APP ROTATION OVERRIDES (Facebook)"

    $fbExists = (& $script:ADB -s $script:SERIAL shell pm list packages -e 2>&1) -join "`n"

    if ($fbExists -match "com\.facebook\.katana") {
        Write-Info "Applying compat overrides for Facebook..."
        Invoke-Adb "am", "compat", "enable", "OVERRIDE_ANY_ORIENTATION", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "enable", "OVERRIDE_ANY_ORIENTATION_TO_USER", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "enable", "OVERRIDE_ENABLE_COMPAT_IGNORE_REQUESTED_ORIENTATION", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "enable", "OVERRIDE_ENABLE_COMPAT_IGNORE_ORIENTATION_REQUEST_WHEN_LOOP_DETECTED", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "enable", "FORCE_RESIZE_APP", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "enable", "OVERRIDE_MIN_ASPECT_RATIO", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "force-stop", "com.facebook.katana" | Out-Null
        Write-Ok "Facebook rotation overrides applied"
    }
    else {
        Write-Info "Facebook not installed - skipping"
    }
}

function Revert-PerAppRotation {
    Write-Header "REVERTING PER-APP ROTATION OVERRIDES"

    $fbExists = (& $script:ADB -s $script:SERIAL shell pm list packages 2>&1) -join "`n"

    if ($fbExists -match "com\.facebook\.katana") {
        Invoke-Adb "am", "compat", "reset", "OVERRIDE_ANY_ORIENTATION", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "reset", "OVERRIDE_ANY_ORIENTATION_TO_USER", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "reset", "OVERRIDE_ENABLE_COMPAT_IGNORE_REQUESTED_ORIENTATION", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "reset", "OVERRIDE_ENABLE_COMPAT_IGNORE_ORIENTATION_REQUEST_WHEN_LOOP_DETECTED", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "reset", "FORCE_RESIZE_APP", "com.facebook.katana" | Out-Null
        Invoke-Adb "am", "compat", "reset", "OVERRIDE_MIN_ASPECT_RATIO", "com.facebook.katana" | Out-Null
        Write-Ok "Facebook rotation overrides removed"
    }
}

function Disable-OsUpdates {
    Write-Header "DISABLE OS UPDATES"

    Write-Warn "This will block Samsung OTA system updates."
    Write-Warn "You will NOT receive security patches or feature updates until reverted."
    Write-Host ""

    # Disable Samsung OTA agent
    $otaPkg = "com.wssyncmldm"
    $enabledPkgs = (& $script:ADB -s $script:SERIAL shell pm list packages -e 2>&1) -join "`n"
    if ($enabledPkgs -match [regex]::Escape($otaPkg)) {
        Write-Info "Disabling Samsung OTA update agent..."
        $result = Invoke-Adb "pm", "disable-user", "--user", "0", $otaPkg
        Write-Ok "Disabled: $otaPkg (Samsung OTA agent)"
    }
    else {
        Write-Info "Samsung OTA agent already disabled or not present"
    }

    # Disable Samsung Software Update
    $soagentPkg = "com.sec.android.soagent"
    if ($enabledPkgs -match [regex]::Escape($soagentPkg)) {
        Write-Info "Disabling Samsung Software Update agent..."
        $result = Invoke-Adb "pm", "disable-user", "--user", "0", $soagentPkg
        Write-Ok "Disabled: $soagentPkg (Software Update agent)"
    }
    else {
        Write-Info "Samsung Software Update agent already disabled or not present"
    }

    # Disable auto-update check setting
    Write-Info "Disabling software update setting..."
    Invoke-Adb "settings", "put", "global", "software_update", "0" | Out-Null
    Write-Ok "Software update check disabled"

    Write-Host ""
    Write-Warn "OS updates are now blocked. Re-enable with: .\optimize-samsung.ps1 -Updates -Revert"
}

function Enable-OsUpdates {
    Write-Header "RE-ENABLING OS UPDATES"

    $disabledPkgs = (& $script:ADB -s $script:SERIAL shell pm list packages -d 2>&1) -join "`n"

    $otaPkg = "com.wssyncmldm"
    if ($disabledPkgs -match [regex]::Escape($otaPkg)) {
        Invoke-Adb "pm", "enable", $otaPkg | Out-Null
        Write-Ok "Re-enabled: $otaPkg (Samsung OTA agent)"
    }

    $soagentPkg = "com.sec.android.soagent"
    if ($disabledPkgs -match [regex]::Escape($soagentPkg)) {
        Invoke-Adb "pm", "enable", $soagentPkg | Out-Null
        Write-Ok "Re-enabled: $soagentPkg (Software Update agent)"
    }

    Invoke-Adb "settings", "put", "global", "software_update", "1" | Out-Null
    Write-Ok "Software update check re-enabled"
    Write-Info "OS updates are now active again."
}

function Set-PrivateDns {
    Write-Header "CONFIGURE PRIVATE DNS"

    # Show current setting
    $currentMode = (& $script:ADB -s $script:SERIAL shell settings get global private_dns_mode 2>&1).Trim()
    $currentHost = (& $script:ADB -s $script:SERIAL shell settings get global private_dns_specifier 2>&1).Trim()

    Write-Host ""
    Write-Info "Current Private DNS mode: $currentMode"
    if ($currentMode -eq "hostname" -and $currentHost -and $currentHost -ne "null") {
        Write-Info "Current DNS provider: $currentHost"
    }
    Write-Host ""

    Write-Host "  Select a DNS provider:" -ForegroundColor White
    Write-Host ""
    Write-Host "   1) " -NoNewline -ForegroundColor White; Write-Host "Cloudflare          " -NoNewline; Write-Host "one.one.one.one (1.1.1.1 - fast, privacy-focused)" -ForegroundColor DarkGray
    Write-Host "   2) " -NoNewline -ForegroundColor White; Write-Host "Google               " -NoNewline; Write-Host "dns.google (8.8.8.8)" -ForegroundColor DarkGray
    Write-Host "   3) " -NoNewline -ForegroundColor White; Write-Host "Quad9                " -NoNewline; Write-Host "dns.quad9.net (9.9.9.9 - malware blocking)" -ForegroundColor DarkGray
    Write-Host "   4) " -NoNewline -ForegroundColor White; Write-Host "AdGuard              " -NoNewline; Write-Host "dns.adguard-dns.com (ad & tracker blocking)" -ForegroundColor DarkGray
    Write-Host "   5) " -NoNewline -ForegroundColor White; Write-Host "NextDNS              " -NoNewline; Write-Host "Requires your NextDNS config ID" -ForegroundColor DarkGray
    Write-Host "   6) " -NoNewline -ForegroundColor White; Write-Host "Custom               " -NoNewline; Write-Host "Enter any DNS-over-TLS hostname" -ForegroundColor DarkGray
    Write-Host ""

    $dnsChoice = Read-Host "  Selection [1-6]"
    $dnsHost = ""

    switch ($dnsChoice) {
        "1" { $dnsHost = "one.one.one.one" }
        "2" { $dnsHost = "dns.google" }
        "3" { $dnsHost = "dns.quad9.net" }
        "4" { $dnsHost = "dns.adguard-dns.com" }
        "5" {
            $nextdnsId = Read-Host "  Enter your NextDNS config ID"
            if (-not $nextdnsId) {
                Write-Fail "No config ID provided. Aborting DNS configuration."
                return
            }
            $dnsHost = "$nextdnsId.dns.nextdns.io"
        }
        "6" {
            $customHost = Read-Host "  Enter DNS-over-TLS hostname"
            if (-not $customHost) {
                Write-Fail "No hostname provided. Aborting DNS configuration."
                return
            }
            $dnsHost = $customHost
        }
        default {
            Write-Fail "Invalid selection. Aborting DNS configuration."
            return
        }
    }

    Write-Host ""
    Write-Info "Setting Private DNS to: $dnsHost"
    Invoke-Adb "settings", "put", "global", "private_dns_specifier", $dnsHost | Out-Null
    Invoke-Adb "settings", "put", "global", "private_dns_mode", "hostname" | Out-Null
    Write-Ok "Private DNS configured: $dnsHost"
    Write-Host ""
    Write-Info "Verify on device: Settings > Connections > More connection settings > Private DNS"
}

function Reset-PrivateDns {
    Write-Header "REVERTING PRIVATE DNS"

    Invoke-Adb "settings", "put", "global", "private_dns_mode", "opportunistic" | Out-Null
    Invoke-Adb "settings", "delete", "global", "private_dns_specifier" | Out-Null
    Write-Ok "Private DNS reset to Automatic (system default)"
    Write-Info "Device will use your network's default DNS servers."
}

function Show-DeviceReport {
    Write-Header "DEVICE STATUS REPORT"

    Write-Host ""
    Write-Host "  Model:              $($script:DEVICE_MODEL)"
    Write-Host "  Device Name:        $($script:DEVICE_NAME)"
    Write-Host "  Android Version:    $($script:ANDROID_VER) (SDK $($script:SDK_VER))"
    Write-Host "  Build:              $((& $script:ADB -s $script:SERIAL shell getprop ro.build.display.id 2>&1).Trim())"

    $meminfo = (& $script:ADB -s $script:SERIAL shell cat /proc/meminfo 2>&1) -join "`n"
    $freeRam = 0
    if ($meminfo -match "MemAvailable:\s+(\d+)") { $freeRam = [int64]$Matches[1] }
    Write-Host "  RAM:                $([math]::Floor($script:RAM_TOTAL_KB / 1024))MB total, $([math]::Floor($freeRam / 1024))MB available"

    $ramPlus = (& $script:ADB -s $script:SERIAL shell settings get global ram_expand_size 2>&1).Trim()
    Write-Host "  RAM Plus:           ${ramPlus}MB"

    $batteryInfo = (& $script:ADB -s $script:SERIAL shell dumpsys battery 2>&1) -join "`n"
    $battLevel = ""; if ($batteryInfo -match "level:\s*(\d+)") { $battLevel = $Matches[1] }
    Write-Host "  Battery:            ${battLevel}%"

    Write-Host "  Uptime:             $((& $script:ADB -s $script:SERIAL shell uptime 2>&1).Trim())"
    Write-Host "  Display:            $((& $script:ADB -s $script:SERIAL shell wm size 2>&1).Trim())"

    Write-Host ""
    Write-Host "  Auto-Rotation:      $((& $script:ADB -s $script:SERIAL shell settings get system accelerometer_rotation 2>&1).Trim())"
    Write-Host "  Orientation Lock:   $((& $script:ADB -s $script:SERIAL shell wm get-ignore-orientation-request 2>&1).Trim())"
    Write-Host "  App Standby:        $((& $script:ADB -s $script:SERIAL shell settings get global app_standby_enabled 2>&1).Trim())"
    Write-Host "  Battery Tip:        $((& $script:ADB -s $script:SERIAL shell settings get global battery_tip_constants 2>&1).Trim())"
    Write-Host "  WiFi Scan Throttle: $((& $script:ADB -s $script:SERIAL shell settings get global wifi_scan_throttle_enabled 2>&1).Trim())"

    $enabledCount = ((& $script:ADB -s $script:SERIAL shell pm list packages -e 2>&1) | Measure-Object).Count
    $disabledCount = ((& $script:ADB -s $script:SERIAL shell pm list packages -d 2>&1) | Measure-Object).Count
    Write-Host "  Packages:           $enabledCount enabled, $disabledCount disabled"
    Write-Host ""
}

# ─── Interactive Menu ─────────────────────────────────────────────────────────

function Show-InteractiveMenu {
    $menuOptions = @()

    # Rotation
    if ($script:DEVICE_TYPE -eq "foldable") {
        $menuOptions += @{ Key = "rotation"; Label = "Rotation & Display Fixes"; Desc = "Auto-rotate all apps + flex mode + app continuity"; Rec = $true }
    }
    else {
        $menuOptions += @{ Key = "rotation"; Label = "Rotation & Display Fixes"; Desc = "Auto-rotate all apps, ignore orientation locks"; Rec = $true }
    }

    # Battery
    $menuOptions += @{ Key = "battery"; Label = "Battery & Power Management"; Desc = "Disable app standby/auto-sleep, WiFi scan throttle"; Rec = $true }

    # Memory
    if ($script:RAM_GB -le 4) {
        $menuOptions += @{ Key = "memory"; Label = "Memory Optimization"; Desc = "Disable RAM Plus to stop swap thrashing ($($script:RAM_GB)GB RAM - critical!)"; Rec = $true }
    }
    elseif ($script:RAM_GB -le 6) {
        $menuOptions += @{ Key = "memory"; Label = "Memory Optimization"; Desc = "Review RAM Plus settings ($($script:RAM_GB)GB RAM)"; Rec = $false }
    }
    else {
        $menuOptions += @{ Key = "memory"; Label = "Memory Optimization"; Desc = "Review RAM Plus settings ($($script:RAM_GB)GB RAM - plenty)"; Rec = $false }
    }

    # Bloatware
    $menuOptions += @{ Key = "bloatware"; Label = "Disable Bloatware"; Desc = "Remove Bixby, Samsung Free, AR Zone, ad services, etc."; Rec = $true }

    # Per-app rotation
    $fbExists = (& $script:ADB -s $script:SERIAL shell pm list packages -e 2>&1) -join "`n"
    if ($fbExists -match "com\.facebook\.katana") {
        $isRecPerApp = ($script:DEVICE_TYPE -eq "foldable" -or $script:DEVICE_TYPE -eq "tablet")
        $menuOptions += @{ Key = "per_app"; Label = "Facebook Rotation Overrides"; Desc = "Force Facebook to respect device rotation"; Rec = $isRecPerApp }
    }

    # Disable updates
    $menuOptions += @{ Key = "updates"; Label = "Disable OS Updates"; Desc = "Block Samsung OTA system updates (not recommended unless needed)"; Rec = $false }

    # DNS
    $menuOptions += @{ Key = "dns"; Label = "Configure Private DNS"; Desc = "Set DNS provider (Cloudflare, Google, Quad9, AdGuard, etc.)"; Rec = $false }

    # Report
    $menuOptions += @{ Key = "report"; Label = "Device Status Report"; Desc = "Show current settings, RAM, battery, packages"; Rec = $true }

    # Display menu
    Write-Host ""
    Write-Host "  Available optimizations for " -NoNewline -ForegroundColor White
    Write-Host $script:DEVICE_MODEL -NoNewline -ForegroundColor Cyan
    Write-Host ":" -ForegroundColor White
    Write-Host ""

    for ($i = 0; $i -lt $menuOptions.Count; $i++) {
        $opt = $menuOptions[$i]
        $marker = if ($opt.Rec) { "*" } else { " " }
        $markerColor = if ($opt.Rec) { "Green" } else { "White" }
        $num = "{0,2}" -f ($i + 1)

        Write-Host "  $num) " -NoNewline -ForegroundColor White
        Write-Host "$marker " -NoNewline -ForegroundColor $markerColor
        Write-Host ("{0,-40}" -f $opt.Label) -NoNewline
        Write-Host $opt.Desc -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  " -NoNewline; Write-Host "* " -NoNewline -ForegroundColor Green; Write-Host "= recommended for this device" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Enter your selection:" -ForegroundColor White
    Write-Host "    Comma-separated numbers (e.g., " -NoNewline; Write-Host "1,2,3" -NoNewline -ForegroundColor Cyan; Write-Host ")"
    Write-Host "    " -NoNewline; Write-Host "all" -NoNewline -ForegroundColor Cyan; Write-Host "  - select everything"
    Write-Host "    " -NoNewline; Write-Host "rec" -NoNewline -ForegroundColor Cyan; Write-Host "  - select recommended only ("; Write-Host -NoNewline "* " -ForegroundColor Green; Write-Host "items)"
    Write-Host "    " -NoNewline; Write-Host "q" -NoNewline -ForegroundColor Cyan; Write-Host "    - quit"
    Write-Host ""

    $selection = Read-Host "  Selection"

    $selectedModules = @()

    switch -Regex ($selection) {
        "^[qQ]" {
            Write-Host ""
            Write-Info "No changes made. Goodbye!"
            exit 0
        }
        "^(all|ALL|a|A)$" {
            $selectedModules = $menuOptions | ForEach-Object { $_.Key }
        }
        "^(rec|REC|r|R|)$" {
            $selectedModules = $menuOptions | Where-Object { $_.Rec } | ForEach-Object { $_.Key }
        }
        default {
            $nums = $selection -split "," | ForEach-Object { $_.Trim() }
            foreach ($num in $nums) {
                if ($num -match "^\d+$") {
                    $idx = [int]$num - 1
                    if ($idx -ge 0 -and $idx -lt $menuOptions.Count) {
                        $selectedModules += $menuOptions[$idx].Key
                    }
                    else {
                        Write-Warn "Ignoring invalid selection: $num"
                    }
                }
            }
        }
    }

    if ($selectedModules.Count -eq 0) {
        Write-Warn "No optimizations selected."
        exit 0
    }

    Write-Host ""
    Write-Host "  Selected:" -ForegroundColor White
    foreach ($key in $selectedModules) {
        $opt = $menuOptions | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        Write-Host "    " -NoNewline; Write-Host "v " -NoNewline -ForegroundColor Green; Write-Host $opt.Label
    }
    Write-Host ""

    if (-not $script:DRY_RUN) {
        $confirm = Read-Host "  Proceed? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = "Y" }
        if ($confirm -notmatch "^[Yy]$") {
            Write-Info "Cancelled. No changes made."
            exit 0
        }
    }
    else {
        Write-Warn "DRY RUN - previewing commands only"
        Write-Host ""
    }

    return $selectedModules
}

function Run-Modules {
    param([string[]]$Modules)

    foreach ($key in $Modules) {
        if ($script:REVERT) {
            switch ($key) {
                "rotation"  { Revert-RotationFixes }
                "battery"   { Revert-BatteryFixes }
                "memory"    { Revert-MemoryFixes }
                "bloatware" { Enable-Bloatware }
                "per_app"   { Revert-PerAppRotation }
                "updates"   { Enable-OsUpdates }
                "dns"       { Reset-PrivateDns }
                "report"    { Show-DeviceReport }
            }
        }
        else {
            switch ($key) {
                "rotation"  { Apply-RotationFixes }
                "battery"   { Apply-BatteryFixes }
                "memory"    { Apply-MemoryFixes }
                "bloatware" { Disable-Bloatware }
                "per_app"   { Apply-PerAppRotation }
                "updates"   { Disable-OsUpdates }
                "dns"       { Set-PrivateDns }
                "report"    { Show-DeviceReport }
            }
        }
    }
}

# ─── Help ─────────────────────────────────────────────────────────────────────

function Show-Usage {
    Write-Host "Samsung Device Optimizer v2.0 (PowerShell)"
    Write-Host ""
    Write-Host "Usage: .\optimize-samsung.ps1 [OPTIONS] [-Serial SERIAL]"
    Write-Host ""
    Write-Host "Modes:"
    Write-Host "  (default)       Interactive - detect device, show optimization menu"
    Write-Host "  -All            Apply all recommended optimizations (no menu)"
    Write-Host "  -DryRun         Preview commands without executing"
    Write-Host "  -Revert         Undo optimizations"
    Write-Host "  -Report         Show device status report only"
    Write-Host ""
    Write-Host "Module flags (non-interactive):"
    Write-Host "  -Rotation       Rotation & display fixes"
    Write-Host "  -Battery        Battery & power management"
    Write-Host "  -Memory         Memory optimization"
    Write-Host "  -Bloatware      Bloatware removal"
    Write-Host "  -PerApp         Per-app rotation overrides"
    Write-Host "  -Updates        Disable/re-enable OS updates"
    Write-Host "  -Dns            Configure Private DNS provider"
    Write-Host ""
    Write-Host "Other:"
    Write-Host "  -InstallAdb     Download and install ADB only"
    Write-Host "  -Help           Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\optimize-samsung.ps1                         # Interactive menu"
    Write-Host "  .\optimize-samsung.ps1 -All                    # Apply all"
    Write-Host "  .\optimize-samsung.ps1 -All -Serial RFCX61GYT3Y"
    Write-Host "  .\optimize-samsung.ps1 -DryRun                 # Preview"
    Write-Host "  .\optimize-samsung.ps1 -Revert                 # Undo all"
    Write-Host "  .\optimize-samsung.ps1 -Bloatware -Rotation    # Specific modules"
    Write-Host "  .\optimize-samsung.ps1 -InstallAdb             # Install ADB only"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

if ($Help) { Show-Usage; exit 0 }

Write-Host ""
Write-Host "  +=============================================+" -ForegroundColor Blue
Write-Host "  |     Samsung Device Optimizer v2.0           |" -ForegroundColor Blue
Write-Host "  |              PowerShell Edition              |" -ForegroundColor Blue
Write-Host "  +=============================================+" -ForegroundColor Blue
Write-Host ""

# Handle -InstallAdb
if ($InstallAdb) {
    if (Find-Adb) {
        $ver = (& $script:ADB version 2>&1 | Select-Object -First 1)
        Write-Ok "ADB is already installed: $ver"
        Write-Info "Location: $($script:ADB)"
    }
    else {
        Install-Adb
    }
    exit 0
}

# Ensure ADB
Ensure-Adb
$adbVer = (& $script:ADB version 2>&1 | Select-Object -First 1) -replace "Android Debug Bridge version ", "ADB "
Write-Info $adbVer

if ($script:DRY_RUN) { Write-Warn "DRY RUN MODE - no changes will be made" }
if ($script:REVERT) { Write-Warn "REVERT MODE - undoing optimizations" }

# Detect device
Detect-Device
Show-DeviceBanner

# Determine what to run
$explicitModules = @()
if ($Rotation)  { $explicitModules += "rotation" }
if ($Battery)   { $explicitModules += "battery" }
if ($Memory)    { $explicitModules += "memory" }
if ($Bloatware) { $explicitModules += "bloatware" }
if ($PerApp)    { $explicitModules += "per_app" }
if ($Updates)   { $explicitModules += "updates" }
if ($Dns)       { $explicitModules += "dns" }

if ($Report) {
    Show-DeviceReport
}
elseif ($explicitModules.Count -gt 0) {
    Run-Modules -Modules $explicitModules
}
elseif ($All) {
    Run-Modules -Modules @("rotation", "battery", "memory", "bloatware", "per_app", "report")
}
else {
    $selected = Show-InteractiveMenu
    Run-Modules -Modules $selected
}

# Finish
Write-Header "COMPLETE"
if ($Report) {
    Write-Info "Report complete."
}
elseif ($script:REVERT) {
    Write-Info "All selected optimizations have been reverted."
    Write-Warn "A reboot is recommended for all changes to take full effect."
}
else {
    Write-Info "All selected optimizations have been applied."
    Write-Warn "A reboot is recommended for all changes to take full effect."
    Write-Host ""
    Write-Info "Manual step: Disable 'Put unused apps to sleep' in:"
    Write-Info "  Settings > Battery > Background usage limits"
    Write-Host ""
    Write-Info "Run '.\optimize-samsung.ps1 -Revert' to undo all changes."
}
Write-Host ""
