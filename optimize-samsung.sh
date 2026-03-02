#!/bin/bash
#
# Samsung Device Optimizer v2.0
# Interactive tool that detects your device and offers tailored optimizations via ADB.
#
# Features:
#   - Auto-detects and installs ADB if missing
#   - Identifies connected Samsung device (foldable, tablet, phone)
#   - Presents device-specific optimization menu
#   - Supports dry-run, revert, and non-interactive modes
#
# Usage:
#   ./optimize-samsung.sh                   # Interactive mode
#   ./optimize-samsung.sh --all             # Apply all optimizations (no menu)
#   ./optimize-samsung.sh --dry-run         # Preview without changes
#   ./optimize-samsung.sh --revert          # Undo all changes
#   ./optimize-samsung.sh --report          # Show device status only
#   ./optimize-samsung.sh [SERIAL]          # Target a specific device

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

DRY_RUN=false
REVERT=false
SERIAL=""
ADB=""
INTERACTIVE=true
REPORT_ONLY=false
RUN_ALL=false
INSTALL_ADB_ONLY=false

# Device info (populated after detection)
DEVICE_MODEL=""
DEVICE_NAME=""
DEVICE_TYPE=""   # foldable | tablet | phone
ANDROID_VER=""
SDK_VER=""
RAM_GB=0
RAM_TOTAL_KB=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Bloatware packages to disable ──────────────────────────────────────────

BLOATWARE_PACKAGES=(
    # Samsung Bixby
    "com.samsung.android.bixby.agent"
    "com.samsung.android.bixby.wakeup"
    "com.samsung.android.bixbyvision.framework"
    # Samsung Extras
    "com.samsung.android.app.spage"           # Samsung Free / Daily
    "com.samsung.android.arzone"              # AR Zone
    "com.samsung.android.visionintelligence"  # Vision Intelligence
    "com.samsung.android.game.gos"            # Game Optimization Service
    "com.samsung.android.game.gametools"      # Game Booster Tools
    "com.samsung.android.app.tips"            # Samsung Tips
    "com.samsung.android.smartsuggestions"     # Smart Suggestions
    "com.samsung.android.rubin.app"           # Samsung Customization Service
    "com.samsung.android.mdecservice"         # Samsung Marketing/Diagnostics
    # Google bloat
    "com.google.android.adservices.api"       # Google Ad Services API
    "com.google.mainline.adservices"          # Google Mainline Ad Services
    "com.google.android.apps.turbo"           # Device Health Services
)

# ─── Helper Functions ────────────────────────────────────────────────────────

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[FAIL]${NC} $1"; }
log_header()  {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

adb_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} adb -s $SERIAL shell $*"
        return 0
    fi
    $ADB -s "$SERIAL" shell "$@" 2>&1
}

# ─── ADB Installation ────────────────────────────────────────────────────────

find_adb() {
    # Check common locations
    local candidates=(
        "adb"
        "$HOME/Android/Sdk/platform-tools/adb"
        "$HOME/android-sdk/platform-tools/adb"
        "/usr/local/bin/adb"
        "/usr/bin/adb"
        "$HOME/platform-tools/adb"
    )

    # Also check if ANDROID_HOME or ANDROID_SDK_ROOT is set
    if [ -n "${ANDROID_HOME:-}" ]; then
        candidates+=("$ANDROID_HOME/platform-tools/adb")
    fi
    if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
        candidates+=("$ANDROID_SDK_ROOT/platform-tools/adb")
    fi

    for candidate in "${candidates[@]}"; do
        if command -v "$candidate" &>/dev/null || [ -x "$candidate" ]; then
            ADB="$candidate"
            return 0
        fi
    done

    return 1
}

detect_platform() {
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    case "$os" in
        linux*)   os="linux" ;;
        darwin*)  os="darwin" ;;
        msys*|mingw*|cygwin*) os="windows" ;;
        *)
            log_error "Unsupported OS: $os"
            return 1
            ;;
    esac

    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)  : ;;
        aarch64|arm64)
            if [ "$os" != "darwin" ]; then
                log_warn "ADB platform-tools are not officially available for Linux ARM64."
                log_info "Try installing via your package manager: sudo apt install adb"
                return 1
            fi
            ;;
    esac

    echo "$os"
}

install_adb() {
    echo ""
    log_header "ADB INSTALLATION"
    echo ""
    log_info "ADB (Android Debug Bridge) is required but was not found on your system."
    echo ""
    echo -e "  ADB is the official Android tool for communicating with devices over USB."
    echo -e "  It will be downloaded from ${CYAN}https://developer.android.com${NC}"
    echo ""

    local platform
    platform=$(detect_platform) || return 1

    local url="https://dl.google.com/android/repository/platform-tools-latest-${platform}.zip"
    local install_dir="$HOME/platform-tools"
    local zip_file="/tmp/platform-tools.zip"

    echo -e "  ${BOLD}Download URL:${NC}  $url"
    echo -e "  ${BOLD}Install to:${NC}    $install_dir"
    echo ""

    read -rp "  Install ADB now? [Y/n] " response
    response=${response:-Y}

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Skipped. Install ADB manually and re-run this script."
        echo ""
        echo "  Manual installation options:"
        echo "    Ubuntu/Debian:  sudo apt install adb"
        echo "    macOS:          brew install android-platform-tools"
        echo "    Download:       $url"
        exit 1
    fi

    echo ""

    # Check for download tools
    local downloader=""
    if command -v curl &>/dev/null; then
        downloader="curl"
    elif command -v wget &>/dev/null; then
        downloader="wget"
    else
        log_error "Neither curl nor wget found. Install one and retry."
        exit 1
    fi

    # Check for unzip
    if ! command -v unzip &>/dev/null; then
        log_error "'unzip' is not installed. Install it first:"
        echo "    Ubuntu/Debian:  sudo apt install unzip"
        echo "    macOS:          brew install unzip"
        exit 1
    fi

    # Download
    log_info "Downloading ADB platform-tools..."
    if [ "$downloader" = "curl" ]; then
        curl -# -L -o "$zip_file" "$url"
    else
        wget --show-progress -q -O "$zip_file" "$url"
    fi

    if [ ! -f "$zip_file" ] || [ ! -s "$zip_file" ]; then
        log_error "Download failed."
        exit 1
    fi
    log_success "Downloaded $(du -h "$zip_file" | awk '{print $1}')"

    # Extract
    log_info "Extracting to $install_dir..."
    rm -rf "$install_dir"
    unzip -q "$zip_file" -d "$HOME"
    rm -f "$zip_file"

    if [ ! -x "$install_dir/adb" ]; then
        log_error "Extraction failed — adb binary not found."
        exit 1
    fi
    log_success "Extracted successfully"

    # Set up PATH
    ADB="$install_dir/adb"
    local path_line='export PATH="$HOME/platform-tools:$PATH"'
    local shell_rc=""

    if [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.profile" ]; then
        shell_rc="$HOME/.profile"
    fi

    if [ -n "$shell_rc" ]; then
        if ! grep -q "platform-tools" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# Android platform-tools (ADB)" >> "$shell_rc"
            echo "$path_line" >> "$shell_rc"
            log_success "Added platform-tools to PATH in $(basename "$shell_rc")"
            log_info "Run 'source $shell_rc' after this script to update your current shell."
        else
            log_info "PATH entry already exists in $(basename "$shell_rc")"
        fi
    else
        log_warn "Could not find shell rc file. Add this to your shell profile:"
        echo "  $path_line"
    fi

    # Verify
    local version
    version=$("$ADB" version 2>/dev/null | head -1)
    echo ""
    log_success "ADB installed: $version"
    echo ""
}

ensure_adb() {
    if find_adb; then
        return 0
    fi

    if [ "$INTERACTIVE" = true ] || [ "$INSTALL_ADB_ONLY" = true ]; then
        install_adb
    else
        log_error "ADB not found. Run interactively to auto-install, or install manually:"
        echo "    Ubuntu/Debian:  sudo apt install adb"
        echo "    macOS:          brew install android-platform-tools"
        echo "    Download:       https://developer.android.com/studio/releases/platform-tools"
        exit 1
    fi
}

# ─── Device Detection ────────────────────────────────────────────────────────

detect_device() {
    local devices
    devices=$($ADB devices 2>/dev/null | grep -w "device" | grep -v "List" | awk '{print $1}')
    local count
    count=$(echo "$devices" | grep -c . 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ]; then
        echo ""
        log_error "No devices connected."
        echo ""
        echo "  Checklist:"
        echo "    1. Device is connected via USB"
        echo "    2. USB Debugging is enabled:"
        echo "       Settings → Developer Options → USB Debugging"
        echo "    3. You've accepted the 'Allow USB debugging?' prompt on the device"
        echo ""
        echo "  To enable Developer Options:"
        echo "    Settings → About Phone → tap 'Build Number' 7 times"
        echo ""
        exit 1
    fi

    if [ -n "$SERIAL" ]; then
        if ! echo "$devices" | grep -q "$SERIAL"; then
            log_error "Device $SERIAL not found. Connected devices:"
            echo "$devices"
            exit 1
        fi
    elif [ "$count" -eq 1 ]; then
        SERIAL=$(echo "$devices" | tr -d '\r')
    else
        # Multiple devices — let user choose
        echo ""
        log_header "MULTIPLE DEVICES DETECTED"
        echo ""

        local i=1
        local serials=()
        while IFS= read -r serial; do
            serial=$(echo "$serial" | tr -d '\r')
            serials+=("$serial")
            local model name
            model=$($ADB -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
            name=$($ADB -s "$serial" shell settings get global device_name 2>/dev/null | tr -d '\r')
            echo -e "  ${BOLD}$i)${NC}  $model — $name  ${DIM}[$serial]${NC}"
            i=$((i + 1))
        done <<< "$devices"

        echo ""
        read -rp "  Select device [1-${#serials[@]}]: " choice
        choice=${choice:-1}

        if [[ "$choice" -lt 1 || "$choice" -gt ${#serials[@]} ]] 2>/dev/null; then
            log_error "Invalid selection."
            exit 1
        fi

        SERIAL="${serials[$((choice - 1))]}"
    fi

    # Populate device info
    DEVICE_MODEL=$($ADB -s "$SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    DEVICE_NAME=$($ADB -s "$SERIAL" shell settings get global device_name 2>/dev/null | tr -d '\r')
    ANDROID_VER=$($ADB -s "$SERIAL" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
    SDK_VER=$($ADB -s "$SERIAL" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
    RAM_TOTAL_KB=$($ADB -s "$SERIAL" shell cat /proc/meminfo 2>/dev/null | grep MemTotal | awk '{print $2}')
    RAM_GB=$(( RAM_TOTAL_KB / 1024 / 1024 ))

    # Determine device type
    # Check model, device name, and Android characteristics
    local model_lower name_lower characteristics
    model_lower=$(echo "$DEVICE_MODEL" | tr '[:upper:]' '[:lower:]')
    name_lower=$(echo "$DEVICE_NAME" | tr '[:upper:]' '[:lower:]')
    characteristics=$($ADB -s "$SERIAL" shell getprop ro.build.characteristics 2>/dev/null | tr -d '\r' | tr '[:upper:]' '[:lower:]')

    if echo "$model_lower $name_lower" | grep -qi "fold\|flip"; then
        DEVICE_TYPE="foldable"
    elif echo "$model_lower $name_lower $characteristics" | grep -qi "tab\|tablet"; then
        DEVICE_TYPE="tablet"
    else
        # Samsung tablets use SM-P or SM-X model prefixes
        if echo "$DEVICE_MODEL" | grep -qiE "^SM-[PX]"; then
            DEVICE_TYPE="tablet"
        else
            DEVICE_TYPE="phone"
        fi
    fi
}

show_device_banner() {
    local type_label
    case "$DEVICE_TYPE" in
        foldable) type_label="Foldable" ;;
        tablet)   type_label="Tablet" ;;
        phone)    type_label="Phone" ;;
    esac

    echo ""
    echo -e "  ${BOLD}Connected Device${NC}"
    echo -e "  ───────────────────────────────────────────"
    echo -e "  ${BOLD}Model:${NC}    $DEVICE_MODEL ($DEVICE_NAME)"
    echo -e "  ${BOLD}Type:${NC}     $type_label"
    echo -e "  ${BOLD}Android:${NC}  $ANDROID_VER (SDK $SDK_VER)"
    echo -e "  ${BOLD}RAM:${NC}      ${RAM_GB}GB ($((RAM_TOTAL_KB / 1024))MB)"
    echo -e "  ${BOLD}Serial:${NC}   ${DIM}$SERIAL${NC}"
    echo ""
}

# ─── Optimization Modules ────────────────────────────────────────────────────

apply_rotation_fixes() {
    log_header "ROTATION & DISPLAY FIXES"

    log_info "Enabling system auto-rotation..."
    adb_cmd settings put system accelerometer_rotation 1
    log_success "Auto-rotation enabled"

    log_info "Enabling rotation suggestions..."
    adb_cmd settings put secure show_rotation_suggestions 1
    log_success "Rotation suggestions enabled"

    log_info "Forcing all apps to follow sensor rotation..."
    adb_cmd wm set-ignore-orientation-request true
    log_success "System-wide orientation override active"

    log_info "Enabling non-resizable multi-window support..."
    adb_cmd settings put global enable_non_resizable_multi_window 1
    log_success "Non-resizable multi-window enabled"

    if [ "$DEVICE_TYPE" = "foldable" ]; then
        log_info "Foldable detected — applying fold-specific settings..."

        log_info "Enabling flex mode panel..."
        adb_cmd settings put global flex_mode_panel_enabled 1
        log_success "Flex mode panel enabled"

        log_info "Enabling app continuity (cover <-> inner screen)..."
        adb_cmd settings put secure foldstar_settings_app_continuity_mode_setting 1
        log_success "App continuity enabled"
    fi

    log_info "Ensuring rotation icon is visible in status bar..."
    if [ "$DRY_RUN" = false ]; then
        local current_blacklist
        current_blacklist=$($ADB -s "$SERIAL" shell settings get secure icon_blacklist 2>/dev/null || echo "")
        local new_blacklist
        new_blacklist=$(echo "$current_blacklist" | sed 's/rotate,*//g; s/,$//' | sed 's/^,//')
        if [ -n "$new_blacklist" ] && [ "$new_blacklist" != "null" ]; then
            adb_cmd settings put secure icon_blacklist "$new_blacklist"
        else
            adb_cmd settings put secure icon_blacklist ""
        fi
    else
        echo -e "${YELLOW}[DRY-RUN]${NC} adb -s $SERIAL shell settings put secure icon_blacklist (cleaned)"
    fi
    log_success "Rotation icon visible in status bar"
}

revert_rotation_fixes() {
    log_header "REVERTING ROTATION & DISPLAY FIXES"

    adb_cmd wm set-ignore-orientation-request false
    log_success "System-wide orientation override removed"

    if [ "$DEVICE_TYPE" = "foldable" ]; then
        adb_cmd settings put global flex_mode_panel_enabled 0
        adb_cmd settings put secure foldstar_settings_app_continuity_mode_setting 0
        log_success "Fold-specific settings reverted"
    fi
}

apply_battery_and_power_fixes() {
    log_header "BATTERY & POWER MANAGEMENT"

    log_info "Disabling app standby (prevents auto app sleeping)..."
    adb_cmd settings put global app_standby_enabled 0
    log_success "App standby disabled"

    log_info "Disabling battery tip app restrictions..."
    adb_cmd settings put global battery_tip_constants "app_restriction_enabled=false"
    log_success "Battery tip restrictions disabled"

    log_info "Enabling WiFi scan throttle..."
    adb_cmd settings put global wifi_scan_throttle_enabled 1
    log_success "WiFi scan throttle enabled"
}

revert_battery_and_power_fixes() {
    log_header "REVERTING BATTERY & POWER MANAGEMENT"

    adb_cmd settings put global app_standby_enabled 1
    log_success "App standby re-enabled"

    adb_cmd settings put global battery_tip_constants "app_restriction_enabled=true"
    log_success "Battery tip restrictions re-enabled"

    adb_cmd settings put global wifi_scan_throttle_enabled 0
    log_success "WiFi scan throttle disabled"
}

apply_memory_fixes() {
    log_header "MEMORY OPTIMIZATION"

    log_info "Device has ~${RAM_GB}GB RAM"

    local current_ram_plus
    current_ram_plus=$($ADB -s "$SERIAL" shell settings get global ram_expand_size 2>/dev/null || echo "null")

    if [ "$RAM_GB" -le 4 ] && [ "$current_ram_plus" != "null" ] && [ "$current_ram_plus" != "0" ]; then
        log_info "Low RAM device with RAM Plus at ${current_ram_plus}MB — disabling to reduce swap thrashing..."
        adb_cmd settings put global ram_expand_size 0
        log_success "RAM Plus disabled (was ${current_ram_plus}MB) — reduces swap thrashing on low-RAM devices"
    elif [ "$current_ram_plus" != "null" ] && [ "$current_ram_plus" != "0" ]; then
        log_info "RAM Plus is at ${current_ram_plus}MB — keeping as-is (device has sufficient RAM)"
    else
        log_info "RAM Plus already at 0 or not available"
    fi
}

revert_memory_fixes() {
    log_header "REVERTING MEMORY OPTIMIZATION"

    if [ "$RAM_GB" -le 4 ]; then
        adb_cmd settings put global ram_expand_size 4096
        log_success "RAM Plus restored to 4GB"
    fi
}

disable_bloatware() {
    log_header "BLOATWARE REMOVAL"

    local disabled_count=0
    local skipped_count=0
    local not_found_count=0

    for pkg in "${BLOATWARE_PACKAGES[@]}"; do
        local exists
        exists=$($ADB -s "$SERIAL" shell pm list packages -e 2>/dev/null | grep -c "$pkg" || true)

        if [ "$exists" -gt 0 ]; then
            local result
            result=$(adb_cmd pm disable-user --user 0 "$pkg" 2>&1)
            if echo "$result" | grep -q "new state: disabled"; then
                log_success "Disabled: $pkg"
                disabled_count=$((disabled_count + 1))
            elif echo "$result" | grep -q "DRY-RUN"; then
                log_success "Would disable: $pkg"
                disabled_count=$((disabled_count + 1))
            else
                log_warn "Could not disable: $pkg — $result"
                skipped_count=$((skipped_count + 1))
            fi
        else
            not_found_count=$((not_found_count + 1))
        fi
    done

    # Disable all Bixby on-device language packs
    log_info "Checking for Bixby on-device language packs..."
    local bixby_packs
    bixby_packs=$($ADB -s "$SERIAL" shell pm list packages -e 2>/dev/null | grep "bixby.ondevice" | sed 's/package://' || true)

    if [ -n "$bixby_packs" ]; then
        while IFS= read -r pkg; do
            pkg=$(echo "$pkg" | tr -d '\r')
            local result
            result=$(adb_cmd pm disable-user --user 0 "$pkg" 2>&1)
            if echo "$result" | grep -q "new state: disabled"; then
                log_success "Disabled: $pkg"
                disabled_count=$((disabled_count + 1))
            elif echo "$result" | grep -q "DRY-RUN"; then
                log_success "Would disable: $pkg"
                disabled_count=$((disabled_count + 1))
            fi
        done <<< "$bixby_packs"
    fi

    echo ""
    log_info "Summary: ${disabled_count} disabled, ${skipped_count} skipped, ${not_found_count} not installed"
}

reenable_bloatware() {
    log_header "RE-ENABLING BLOATWARE"

    for pkg in "${BLOATWARE_PACKAGES[@]}"; do
        local exists
        exists=$($ADB -s "$SERIAL" shell pm list packages -d 2>/dev/null | grep -c "$pkg" || true)
        if [ "$exists" -gt 0 ]; then
            adb_cmd pm enable "$pkg" 2>&1 | grep -q "new state" && log_success "Re-enabled: $pkg"
        fi
    done

    local bixby_packs
    bixby_packs=$($ADB -s "$SERIAL" shell pm list packages -d 2>/dev/null | grep "bixby.ondevice" | sed 's/package://' || true)
    if [ -n "$bixby_packs" ]; then
        while IFS= read -r pkg; do
            pkg=$(echo "$pkg" | tr -d '\r')
            adb_cmd pm enable "$pkg" 2>&1 | grep -q "new state" && log_success "Re-enabled: $pkg"
        done <<< "$bixby_packs"
    fi
}

apply_per_app_rotation() {
    log_header "PER-APP ROTATION OVERRIDES (Facebook)"

    local fb_exists
    fb_exists=$($ADB -s "$SERIAL" shell pm list packages -e 2>/dev/null | grep -c "com.facebook.katana" || true)

    if [ "$fb_exists" -gt 0 ]; then
        log_info "Applying compat overrides for Facebook..."
        adb_cmd am compat enable OVERRIDE_ANY_ORIENTATION com.facebook.katana
        adb_cmd am compat enable OVERRIDE_ANY_ORIENTATION_TO_USER com.facebook.katana
        adb_cmd am compat enable OVERRIDE_ENABLE_COMPAT_IGNORE_REQUESTED_ORIENTATION com.facebook.katana
        adb_cmd am compat enable OVERRIDE_ENABLE_COMPAT_IGNORE_ORIENTATION_REQUEST_WHEN_LOOP_DETECTED com.facebook.katana
        adb_cmd am compat enable FORCE_RESIZE_APP com.facebook.katana
        adb_cmd am compat enable OVERRIDE_MIN_ASPECT_RATIO com.facebook.katana
        adb_cmd am force-stop com.facebook.katana
        log_success "Facebook rotation overrides applied"
    else
        log_info "Facebook not installed — skipping"
    fi
}

revert_per_app_rotation() {
    log_header "REVERTING PER-APP ROTATION OVERRIDES"

    local fb_exists
    fb_exists=$($ADB -s "$SERIAL" shell pm list packages 2>/dev/null | grep -c "com.facebook.katana" || true)

    if [ "$fb_exists" -gt 0 ]; then
        adb_cmd am compat reset OVERRIDE_ANY_ORIENTATION com.facebook.katana
        adb_cmd am compat reset OVERRIDE_ANY_ORIENTATION_TO_USER com.facebook.katana
        adb_cmd am compat reset OVERRIDE_ENABLE_COMPAT_IGNORE_REQUESTED_ORIENTATION com.facebook.katana
        adb_cmd am compat reset OVERRIDE_ENABLE_COMPAT_IGNORE_ORIENTATION_REQUEST_WHEN_LOOP_DETECTED com.facebook.katana
        adb_cmd am compat reset FORCE_RESIZE_APP com.facebook.katana
        adb_cmd am compat reset OVERRIDE_MIN_ASPECT_RATIO com.facebook.katana
        log_success "Facebook rotation overrides removed"
    fi
}

show_device_report() {
    log_header "DEVICE STATUS REPORT"

    echo ""
    echo "  Model:              $DEVICE_MODEL"
    echo "  Device Name:        $DEVICE_NAME"
    echo "  Android Version:    $ANDROID_VER (SDK $SDK_VER)"
    echo "  Build:              $($ADB -s "$SERIAL" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"

    local free_ram
    free_ram=$($ADB -s "$SERIAL" shell cat /proc/meminfo 2>/dev/null | grep MemAvailable | awk '{print $2}')
    echo "  RAM:                $((RAM_TOTAL_KB / 1024))MB total, $((free_ram / 1024))MB available"

    local ram_plus
    ram_plus=$($ADB -s "$SERIAL" shell settings get global ram_expand_size 2>/dev/null || echo "N/A")
    echo "  RAM Plus:           ${ram_plus}MB"

    echo "  Battery:            $($ADB -s "$SERIAL" shell dumpsys battery 2>/dev/null | grep level | head -1 | awk '{print $2}')%"
    echo "  Uptime:             $($ADB -s "$SERIAL" shell uptime 2>/dev/null | sed 's/.*up /up /' | sed 's/,.*//')"
    echo "  Display:            $($ADB -s "$SERIAL" shell wm size 2>/dev/null | awk '{print $3}')"

    echo ""
    echo "  Auto-Rotation:      $($ADB -s "$SERIAL" shell settings get system accelerometer_rotation 2>/dev/null | tr -d '\r')"
    echo "  Orientation Lock:   $($ADB -s "$SERIAL" shell wm get-ignore-orientation-request 2>/dev/null | tr -d '\r')"
    echo "  App Standby:        $($ADB -s "$SERIAL" shell settings get global app_standby_enabled 2>/dev/null | tr -d '\r')"
    echo "  Battery Tip:        $($ADB -s "$SERIAL" shell settings get global battery_tip_constants 2>/dev/null | tr -d '\r')"
    echo "  WiFi Scan Throttle: $($ADB -s "$SERIAL" shell settings get global wifi_scan_throttle_enabled 2>/dev/null | tr -d '\r')"

    local enabled_count
    enabled_count=$($ADB -s "$SERIAL" shell pm list packages -e 2>/dev/null | wc -l)
    local disabled_count
    disabled_count=$($ADB -s "$SERIAL" shell pm list packages -d 2>/dev/null | wc -l)
    echo "  Packages:           ${enabled_count} enabled, ${disabled_count} disabled"
    echo ""
}

# ─── Interactive Menu ─────────────────────────────────────────────────────────

MENU_OPTIONS=()
SELECTED_MODULES=()

build_menu() {
    # Build optimization options based on device type
    # Each entry: "key|label|description|recommended"
    MENU_OPTIONS=()

    # --- Rotation ---
    if [ "$DEVICE_TYPE" = "foldable" ]; then
        MENU_OPTIONS+=("rotation|Rotation & Display Fixes|Auto-rotate all apps + flex mode + app continuity|yes")
    elif [ "$DEVICE_TYPE" = "tablet" ]; then
        MENU_OPTIONS+=("rotation|Rotation & Display Fixes|Auto-rotate all apps, ignore orientation locks|yes")
    else
        MENU_OPTIONS+=("rotation|Rotation & Display Fixes|Auto-rotate all apps, ignore orientation locks|yes")
    fi

    # --- Battery ---
    MENU_OPTIONS+=("battery|Battery & Power Management|Disable app standby/auto-sleep, WiFi scan throttle|yes")

    # --- Memory ---
    if [ "$RAM_GB" -le 4 ]; then
        MENU_OPTIONS+=("memory|Memory Optimization|Disable RAM Plus to stop swap thrashing (${RAM_GB}GB RAM — critical!)|yes")
    elif [ "$RAM_GB" -le 6 ]; then
        MENU_OPTIONS+=("memory|Memory Optimization|Review RAM Plus settings (${RAM_GB}GB RAM)|no")
    else
        MENU_OPTIONS+=("memory|Memory Optimization|Review RAM Plus settings (${RAM_GB}GB RAM — plenty)|no")
    fi

    # --- Bloatware ---
    MENU_OPTIONS+=("bloatware|Disable Bloatware|Remove Bixby, Samsung Free, AR Zone, ad services, etc.|yes")

    # --- Per-app rotation ---
    local fb_installed
    fb_installed=$($ADB -s "$SERIAL" shell pm list packages -e 2>/dev/null | grep -c "com.facebook.katana" || true)
    if [ "$fb_installed" -gt 0 ]; then
        if [ "$DEVICE_TYPE" = "foldable" ] || [ "$DEVICE_TYPE" = "tablet" ]; then
            MENU_OPTIONS+=("per_app|Facebook Rotation Overrides|Force Facebook to respect device rotation|yes")
        else
            MENU_OPTIONS+=("per_app|Facebook Rotation Overrides|Force Facebook to respect device rotation|no")
        fi
    fi

    # --- Report ---
    MENU_OPTIONS+=("report|Device Status Report|Show current settings, RAM, battery, packages|yes")
}

show_interactive_menu() {
    echo ""
    echo -e "  ${BOLD}Available optimizations for ${CYAN}${DEVICE_MODEL}${NC}${BOLD}:${NC}"
    echo ""

    local i=1
    for opt in "${MENU_OPTIONS[@]}"; do
        IFS='|' read -r key label desc default <<< "$opt"
        local marker
        if [ "$default" = "yes" ]; then
            marker="${GREEN}*${NC}"
        else
            marker=" "
        fi
        printf "  ${BOLD}%2d)${NC} %b %-40s ${DIM}%s${NC}\n" "$i" "$marker" "$label" "$desc"
        i=$((i + 1))
    done

    echo ""
    echo -e "  ${DIM}${GREEN}*${NC} = recommended for this device${NC}"
    echo ""
    echo -e "  ${BOLD}Enter your selection:${NC}"
    echo -e "    Comma-separated numbers (e.g., ${CYAN}1,2,3${NC})"
    echo -e "    ${CYAN}all${NC}  — select everything"
    echo -e "    ${CYAN}rec${NC}  — select recommended only (${GREEN}*${NC} items)"
    echo -e "    ${CYAN}q${NC}    — quit"
    echo ""
    read -rp "  Selection: " selection

    SELECTED_MODULES=()

    case "$selection" in
        q|Q|quit|exit)
            echo ""
            log_info "No changes made. Goodbye!"
            exit 0
            ;;
        all|ALL|a|A)
            for opt in "${MENU_OPTIONS[@]}"; do
                IFS='|' read -r key _ _ _ <<< "$opt"
                SELECTED_MODULES+=("$key")
            done
            ;;
        rec|REC|r|R|"")
            for opt in "${MENU_OPTIONS[@]}"; do
                IFS='|' read -r key _ _ default <<< "$opt"
                if [ "$default" = "yes" ]; then
                    SELECTED_MODULES+=("$key")
                fi
            done
            ;;
        *)
            IFS=',' read -ra nums <<< "$selection"
            for num in "${nums[@]}"; do
                num=$(echo "$num" | tr -d ' ')
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#MENU_OPTIONS[@]} ]; then
                    local opt="${MENU_OPTIONS[$((num - 1))]}"
                    IFS='|' read -r key _ _ _ <<< "$opt"
                    SELECTED_MODULES+=("$key")
                else
                    log_warn "Ignoring invalid selection: $num"
                fi
            done
            ;;
    esac

    if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
        log_warn "No optimizations selected."
        exit 0
    fi

    echo ""
    echo -e "  ${BOLD}Selected:${NC}"
    for key in "${SELECTED_MODULES[@]}"; do
        for opt in "${MENU_OPTIONS[@]}"; do
            IFS='|' read -r k label _ _ <<< "$opt"
            if [ "$k" = "$key" ]; then
                echo -e "    ${GREEN}✓${NC} $label"
            fi
        done
    done
    echo ""

    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN — previewing commands only"
        echo ""
    else
        read -rp "  Proceed? [Y/n] " confirm
        confirm=${confirm:-Y}
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Cancelled. No changes made."
            exit 0
        fi
    fi
}

run_modules() {
    local modules=("$@")

    for key in "${modules[@]}"; do
        if [ "$REVERT" = true ]; then
            case "$key" in
                rotation)  revert_rotation_fixes ;;
                battery)   revert_battery_and_power_fixes ;;
                memory)    revert_memory_fixes ;;
                bloatware) reenable_bloatware ;;
                per_app)   revert_per_app_rotation ;;
                report)    show_device_report ;;
            esac
        else
            case "$key" in
                rotation)  apply_rotation_fixes ;;
                battery)   apply_battery_and_power_fixes ;;
                memory)    apply_memory_fixes ;;
                bloatware) disable_bloatware ;;
                per_app)   apply_per_app_rotation ;;
                report)    show_device_report ;;
            esac
        fi
    done
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────

usage() {
    echo "Samsung Device Optimizer v2.0"
    echo ""
    echo "Usage: $0 [OPTIONS] [SERIAL]"
    echo ""
    echo "Modes:"
    echo "  (default)       Interactive — detect device, show optimization menu"
    echo "  --all           Apply all recommended optimizations (no menu)"
    echo "  --dry-run       Preview commands without executing"
    echo "  --revert        Undo optimizations (works with --all or interactive)"
    echo "  --report        Show device status report only"
    echo ""
    echo "Module flags (non-interactive):"
    echo "  --bloatware     Only disable/enable bloatware"
    echo "  --rotation      Only apply/revert rotation fixes"
    echo "  --battery       Only apply/revert battery & power fixes"
    echo "  --memory        Only apply/revert memory fixes"
    echo "  --per-app       Only apply/revert per-app rotation overrides"
    echo ""
    echo "Other:"
    echo "  --install-adb   Download and install ADB only"
    echo "  -h, --help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                              # Interactive menu"
    echo "  $0 --all                        # Apply all, auto-detect device"
    echo "  $0 --all RFCX61GYT3Y           # Apply all to specific device"
    echo "  $0 --dry-run                    # Interactive preview"
    echo "  $0 --revert                     # Interactive revert menu"
    echo "  $0 --bloatware --rotation       # Only bloatware + rotation"
    echo "  $0 --install-adb                # Install ADB only"
}

EXPLICIT_MODULES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)      DRY_RUN=true; shift ;;
        --revert)       REVERT=true; shift ;;
        --all)          RUN_ALL=true; INTERACTIVE=false; shift ;;
        --report)       REPORT_ONLY=true; INTERACTIVE=false; shift ;;
        --bloatware)    EXPLICIT_MODULES+=("bloatware"); INTERACTIVE=false; shift ;;
        --rotation)     EXPLICIT_MODULES+=("rotation"); INTERACTIVE=false; shift ;;
        --battery)      EXPLICIT_MODULES+=("battery"); INTERACTIVE=false; shift ;;
        --memory)       EXPLICIT_MODULES+=("memory"); INTERACTIVE=false; shift ;;
        --per-app)      EXPLICIT_MODULES+=("per_app"); INTERACTIVE=false; shift ;;
        --install-adb)  INSTALL_ADB_ONLY=true; shift ;;
        -h|--help)      usage; exit 0 ;;
        -*)             log_error "Unknown option: $1"; echo ""; usage; exit 1 ;;
        *)              SERIAL="$1"; shift ;;
    esac
done

# ─── Main Execution ──────────────────────────────────────────────────────────

echo -e "${BLUE}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║     Samsung Device Optimizer v2.0         ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# --- Handle --install-adb ---
if [ "$INSTALL_ADB_ONLY" = true ]; then
    if find_adb; then
        adb_ver=$("$ADB" version 2>/dev/null | head -1)
        log_success "ADB is already installed: $adb_ver"
        log_info "Location: $(command -v "$ADB" 2>/dev/null || echo "$ADB")"
    else
        install_adb
    fi
    exit 0
fi

# --- Ensure ADB is available ---
ensure_adb
adb_ver=$("$ADB" version 2>/dev/null | head -1 | sed 's/Android Debug Bridge version /ADB /')
log_info "$adb_ver"

if [ "$DRY_RUN" = true ]; then
    log_warn "DRY RUN MODE — no changes will be made"
fi
if [ "$REVERT" = true ]; then
    log_warn "REVERT MODE — undoing optimizations"
fi

# --- Detect & display device ---
detect_device
show_device_banner

# --- Execute ---
if [ "$REPORT_ONLY" = true ]; then
    show_device_report
elif [ ${#EXPLICIT_MODULES[@]} -gt 0 ]; then
    run_modules "${EXPLICIT_MODULES[@]}"
elif [ "$RUN_ALL" = true ]; then
    run_modules "rotation" "battery" "memory" "bloatware" "per_app" "report"
else
    build_menu
    show_interactive_menu
    run_modules "${SELECTED_MODULES[@]}"
fi

# --- Finish ---
log_header "COMPLETE"
if [ "$REPORT_ONLY" = true ]; then
    log_info "Report complete."
elif [ "$REVERT" = true ]; then
    log_info "All selected optimizations have been reverted."
    log_warn "A reboot is recommended for all changes to take full effect."
else
    log_info "All selected optimizations have been applied."
    log_warn "A reboot is recommended for all changes to take full effect."
    echo ""
    log_info "Manual step: Disable 'Put unused apps to sleep' in:"
    log_info "  Settings > Battery > Background usage limits"
    echo ""
    log_info "Run '$0 --revert' to undo all changes."
fi
echo ""
