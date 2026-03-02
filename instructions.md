# Samsung Device Optimizer v2.0 — Instructions

Interactive ADB-based optimization toolkit for Samsung Galaxy devices. Auto-detects your device, offers to install ADB if missing, and presents a tailored menu of optimizations.

---

## Quick Start

```bash
# Make the script executable
chmod +x optimize-samsung.sh

# Interactive mode — detects device, shows optimization menu
./optimize-samsung.sh

# Apply all recommended optimizations (no menu)
./optimize-samsung.sh --all

# Preview what would change without applying anything
./optimize-samsung.sh --dry-run

# Target a specific device when multiple are connected
./optimize-samsung.sh RFCX61GYT3Y
```

---

## Prerequisites

- **USB Debugging** enabled on the Samsung device (Settings → Developer options → USB debugging)
- Device connected via USB and authorized (you've accepted the "Allow USB debugging?" prompt on the phone)
- **ADB** — the script will auto-detect it or **offer to download and install it** if not found

### First-time ADB setup

If you don't have ADB installed, the script will:
1. Detect your OS (Linux, macOS, Windows/MSYS)
2. Download the official platform-tools from Google
3. Extract to `~/platform-tools`
4. Add it to your shell PATH automatically

You can also install ADB independently:
```bash
# Auto-install ADB only (no device needed)
./optimize-samsung.sh --install-adb

# Or install manually:
# Ubuntu/Debian:  sudo apt install adb
# macOS:          brew install android-platform-tools
# Download:       https://developer.android.com/studio/releases/platform-tools
```

Verify with:
```bash
adb devices
# Should show your device as "device" (not "unauthorized")
```

---

## Device Detection

When launched, the script automatically identifies:

| Check | How |
|---|---|
| **Device type** | Model string (`Fold`/`Flip` → foldable), device name (`Tab` → tablet), model prefix (`SM-P`/`SM-X` → tablet), Android `ro.build.characteristics` |
| **RAM** | Reads `/proc/meminfo` — devices ≤4GB get memory optimization recommended |
| **Installed apps** | Checks for Facebook to offer per-app rotation overrides |

The interactive menu marks recommended optimizations with `*` based on these checks. For example, a Z Fold 6 (12GB) gets flex mode + app continuity recommended but not memory fixes, while a Tab S6 Lite (4GB) gets memory optimization flagged as critical.

---

## What It Does

The script applies **five categories** of optimizations, tailored to the detected device:

### 1. Rotation & Display Fixes

| Setting | What it does |
|---|---|
| Auto-rotation ON | Enables system-wide accelerometer rotation |
| Rotation suggestions | Shows a rotation button in the nav bar when the app orientation doesn't match |
| **Ignore orientation requests** | System-wide override — forces ALL apps to follow the sensor instead of locking to portrait/landscape |
| Non-resizable multi-window | Allows apps that don't officially support split-screen to work in multi-window mode |
| **Flex mode panel** _(Fold only)_ | Enables the flex mode panel when the phone is half-folded |
| **App continuity** _(Fold only)_ | Seamless transition when moving apps between cover and inner screen |
| Status bar rotation icon | Removes "rotate" from the icon blacklist so it's visible |

**Per-App Overrides (Facebook):**

Facebook aggressively locks to portrait at runtime. The script applies Android compat framework overrides:

| Override | Purpose |
|---|---|
| `OVERRIDE_ANY_ORIENTATION` | Ignores the app's static orientation declaration |
| `OVERRIDE_ANY_ORIENTATION_TO_USER` | Forces rotation to follow the sensor |
| `OVERRIDE_ENABLE_COMPAT_IGNORE_REQUESTED_ORIENTATION` | Ignores runtime `setRequestedOrientation()` calls |
| `OVERRIDE_ENABLE_COMPAT_IGNORE_ORIENTATION_REQUEST_WHEN_LOOP_DETECTED` | Stops apps that repeatedly re-request portrait in a loop |
| `FORCE_RESIZE_APP` | Allows the app to resize to any aspect ratio |
| `OVERRIDE_MIN_ASPECT_RATIO` | Removes minimum aspect ratio restrictions |

To apply these overrides to **other stubborn apps**, add similar `am compat enable` blocks in the `apply_per_app_rotation()` function.

### 2. Battery & Power Management

| Setting | What it does |
|---|---|
| **App standby disabled** | Prevents Android from bucketing apps into restricted/rare usage tiers that eventually disable them |
| **Battery tip restrictions disabled** | Stops Samsung Device Care from suggesting "restrict this app" notifications |
| **WiFi scan throttle enabled** | Reduces background WiFi scanning frequency to save CPU and battery |

> **Important:** You should also go on-device to **Settings → Battery → Background usage limits** and toggle OFF **"Put unused apps to sleep"**. This Samsung setting cannot be fully controlled via ADB.

### 3. Memory Optimization

| Setting | What it does |
|---|---|
| **RAM Plus → 0** _(4GB devices only)_ | On low-RAM devices, Samsung's virtual RAM (RAM Plus) causes severe swap thrashing. Disabling it forces Android to kill unused apps instead of swapping, which is actually much faster. Only applied to devices with ≤4GB RAM. |

### 4. Bloatware Removal

Disables (not uninstalls) the following packages. They can be re-enabled at any time with `--revert`:

| Package | What it is |
|---|---|
| `com.samsung.android.bixby.agent` | Bixby Voice |
| `com.samsung.android.bixby.wakeup` | "Hi Bixby" wake word |
| `com.samsung.android.bixby.ondevice.*` | Bixby on-device language models (all languages) |
| `com.samsung.android.bixbyvision.framework` | Bixby Vision (camera AI) |
| `com.samsung.android.app.spage` | Samsung Free / Samsung Daily |
| `com.samsung.android.arzone` | AR Zone (AR doodles, emoji) |
| `com.samsung.android.visionintelligence` | Vision Intelligence |
| `com.samsung.android.game.gos` | Game Optimization Service (throttles performance) |
| `com.samsung.android.game.gametools` | Game Booster Tools |
| `com.samsung.android.app.tips` | Samsung Tips |
| `com.samsung.android.smartsuggestions` | Smart Suggestions |
| `com.samsung.android.rubin.app` | Samsung Customization Service (telemetry) |
| `com.samsung.android.mdecservice` | Samsung Marketing / Diagnostics |
| `com.google.android.adservices.api` | Google Ad Services API |
| `com.google.mainline.adservices` | Google Mainline Ad Services |
| `com.google.android.apps.turbo` | Device Health Services |

**Estimated RAM savings:** ~400-500MB (significant on 4GB devices)

### 5. Per-App Rotation Overrides

For apps like Facebook that aggressively lock to portrait at runtime, the script applies Android compat framework overrides to force them to follow the device sensor. See the Rotation & Display section above for the full list of overrides applied.

---

## Usage

### Interactive mode (default)
```bash
./optimize-samsung.sh
```
The script will:
1. Check for ADB (offer to install if missing)
2. Detect the connected device (or let you pick if multiple are connected)
3. Identify the device type (foldable, tablet, phone)
4. Show a tailored menu of optimizations with recommendations marked
5. Let you pick which to apply

**Menu selection options:**
- Enter numbers: `1,2,3` or `1,3,5`
- `all` — select everything
- `rec` — select only the recommended items (marked with `*`)
- `q` — quit

### Apply all (non-interactive)
```bash
./optimize-samsung.sh --all
```

### Dry run (preview only)
```bash
./optimize-samsung.sh --dry-run        # Interactive preview
./optimize-samsung.sh --all --dry-run  # Non-interactive preview
```

### Revert all changes
```bash
./optimize-samsung.sh --revert         # Interactive revert menu
./optimize-samsung.sh --all --revert   # Revert everything
```

### Apply only specific modules
```bash
./optimize-samsung.sh --rotation       # Rotation fixes only
./optimize-samsung.sh --battery        # Battery/power fixes only
./optimize-samsung.sh --memory         # Memory fixes only
./optimize-samsung.sh --bloatware      # Bloatware removal only
./optimize-samsung.sh --per-app        # Facebook rotation overrides only
```

### Revert specific modules
```bash
./optimize-samsung.sh --rotation --revert    # Revert rotation only
./optimize-samsung.sh --bloatware --revert   # Re-enable bloatware only
```

### Device status report
```bash
./optimize-samsung.sh --report
```

### Multiple devices
When multiple devices are connected, the script shows a numbered list and lets you pick:
```
  1)  SM-F956U1 — TALBOT's Z Fold 6  [RFCX61GYT3Y]
  2)  SM-P620 — TALBOT's Tab S6 Lite  [R52Y5057J4Y]

  Select device [1-2]:
```

Or specify a serial directly:
```bash
./optimize-samsung.sh RFCX61GYT3Y     # Z Fold 6
./optimize-samsung.sh R52Y5057J4Y     # Tab S6 Lite
```

### Install ADB only
```bash
./optimize-samsung.sh --install-adb
```

---

## Post-Script Manual Steps

These optimizations **must be done on the device** (not available via ADB):

1. **Disable "Put unused apps to sleep"**
   - Settings → Battery → Background usage limits → Toggle OFF
   - Clear the Sleeping apps and Deep sleeping apps lists
   - Add critical apps to the "Never sleeping apps" list

2. **Full screen apps** _(Fold devices)_
   - Settings → Display → Screen layout and zoom → Full screen apps
   - Toggle specific apps to full-screen on the inner display

3. **Consider replacing heavy apps**
   - Facebook + Messenger use ~300MB combined. Facebook Lite + Messenger Lite use ~50MB.
   - Heavy third-party launchers (e.g., Square Home at 235MB) can be replaced with lighter alternatives

4. **Storage cleanup**
   - Keep storage below 80% full for optimal I/O performance
   - Move photos/videos to cloud or SD card

5. **Reboot after applying**
   - A reboot ensures all changes (especially RAM Plus and bloatware) take full effect

---

## Troubleshooting

### An app is broken after disabling
```bash
# Re-enable a specific package
adb shell pm enable com.package.name
```

### Rotation override causes layout issues in a specific app
```bash
# The system-wide override can be toggled off
adb shell wm set-ignore-orientation-request false

# Or reset compat overrides for a specific app
adb shell am compat reset OVERRIDE_ANY_ORIENTATION com.package.name
adb shell am compat reset OVERRIDE_ANY_ORIENTATION_TO_USER com.package.name
```

### Device feels slower after disabling RAM Plus
This is temporary — Android needs to adjust its memory management after reducing swap. Give it a few hours of use. If it persists:
```bash
adb shell settings put global ram_expand_size 2048   # Set to 2GB instead of 0
```

### Changes didn't survive a reboot
Most settings persist. The `wm set-ignore-orientation-request` command may need to be re-applied after a reboot on some firmware versions. If so, run:
```bash
./optimize-samsung.sh --rotation
```

---

## Adding More Apps for Rotation Override

To force rotation on other stubborn apps, find the package name and run:
```bash
adb shell am compat enable OVERRIDE_ANY_ORIENTATION com.example.app
adb shell am compat enable OVERRIDE_ANY_ORIENTATION_TO_USER com.example.app
adb shell am compat enable OVERRIDE_ENABLE_COMPAT_IGNORE_REQUESTED_ORIENTATION com.example.app
adb shell am compat enable FORCE_RESIZE_APP com.example.app
adb shell am force-stop com.example.app
```

To find an app's package name:
```bash
adb shell pm list packages | grep -i "appname"
```

---

## Tested On

| Device | Model | Android | Detected As | Status |
|---|---|---|---|---|
| Galaxy Z Fold 6 | SM-F956U1 | 16 (SDK 36) | Foldable | ✅ Verified |
| Galaxy Tab S6 Lite | SM-P620 | 16 (SDK 36) | Tablet | ✅ Verified |
