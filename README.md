# Samsung Device Optimizer

An interactive ADB toolkit that detects your Samsung Galaxy device and applies safe, reversible optimizations — rotation fixes, bloatware removal, battery management, and memory tuning.

**No root required.** Everything is done through standard ADB commands and can be reverted instantly.

## Features

- **Cross-platform** — bash for Linux/macOS, PowerShell + batch for Windows
- **Auto-installs ADB** if not found on your system (downloads official Google platform-tools)
- **Detects your device** — identifies foldables (Fold/Flip), tablets, and phones automatically
- **Interactive menu** — shows recommended optimizations tailored to the connected device
- **Dry-run mode** — preview every command before applying
- **Fully reversible** — `--revert` undoes all changes
- **Multi-device support** — pick from connected devices or specify a serial number

## Quick Start

### Linux / macOS

```bash
git clone https://github.com/mr-tbot/Samsung-Optimizer-Rotation-Enabler.git
cd Samsung-Optimizer-Rotation-Enabler
chmod +x optimize-samsung.sh

# Interactive — detects device, shows menu
./optimize-samsung.sh

# Or apply everything at once
./optimize-samsung.sh --all

# Preview without changing anything
./optimize-samsung.sh --dry-run
```

### Windows

```powershell
git clone https://github.com/mr-tbot/Samsung-Optimizer-Rotation-Enabler.git
cd Samsung-Optimizer-Rotation-Enabler

# Option 1: Double-click optimize-samsung.bat
# Option 2: Run from PowerShell
.\optimize-samsung.ps1

# Or from Command Prompt
optimize-samsung.bat --all
```

> Don't have ADB? The script will offer to download and install it for you.
> Linux/macOS: `./optimize-samsung.sh --install-adb`
> Windows: `optimize-samsung.bat --install-adb` or `.\optimize-samsung.ps1 -InstallAdb`

## What It Optimizes

| Module | What it does | Devices |
|---|---|---|
| **Rotation** | Force all apps to follow sensor rotation, enable flex mode & app continuity | All (fold-specific extras on foldables) |
| **Battery** | Disable app standby & auto-sleep, WiFi scan throttle | All |
| **Memory** | Disable RAM Plus to stop swap thrashing | ≤4GB RAM devices |
| **Bloatware** | Disable Bixby, Samsung Free, AR Zone, Game Optimizer, ad services (16+ packages) | All |
| **Per-App Rotation** | Compat framework overrides for Facebook and other stubborn apps | Foldables & tablets |
| **OS Updates** | Disable Samsung OTA system updates (opt-in only, not recommended by default) | All |

## Usage

### Linux / macOS (bash)

```
./optimize-samsung.sh [OPTIONS] [SERIAL]

Modes:
  (default)       Interactive — detect device, show optimization menu
  --all           Apply all recommended optimizations (no menu)
  --dry-run       Preview commands without executing
  --revert        Undo optimizations
  --report        Show device status report only
  --install-adb   Download and install ADB only

Module flags (non-interactive):
  --rotation      Rotation & display fixes
  --battery       Battery & power management
  --memory        Memory optimization
  --bloatware     Bloatware removal
  --per-app       Per-app rotation overrides
  --updates       Disable/re-enable OS updates

  -h, --help      Show help
```

### Windows (PowerShell)

```
.\optimize-samsung.ps1 [OPTIONS] [-Serial SERIAL]

Modes:
  (default)       Interactive — detect device, show optimization menu
  -All            Apply all recommended optimizations (no menu)
  -DryRun         Preview commands without executing
  -Revert         Undo optimizations
  -Report         Show device status report only
  -InstallAdb     Download and install ADB only

Module flags:
  -Rotation       Rotation & display fixes
  -Battery        Battery & power management
  -Memory         Memory optimization
  -Bloatware      Bloatware removal
  -PerApp         Per-app rotation overrides
  -Updates        Disable/re-enable OS updates
```

### Windows (Command Prompt via .bat)

The `.bat` file accepts the same `--flags` as the bash script and passes them through to PowerShell:

```cmd
optimize-samsung.bat                         # Interactive
optimize-samsung.bat --all                   # Apply all
optimize-samsung.bat --dry-run               # Preview
optimize-samsung.bat --revert                # Undo
optimize-samsung.bat --install-adb           # Install ADB
optimize-samsung.bat --updates               # Disable OS updates
optimize-samsung.bat RFCX61GYT3Y             # Target specific device
```

### Examples

```bash
./optimize-samsung.sh                         # Interactive menu
./optimize-samsung.sh --all                   # Apply all, auto-detect device
./optimize-samsung.sh --all RFCX61GYT3Y      # Apply all to specific device
./optimize-samsung.sh --dry-run               # Interactive preview
./optimize-samsung.sh --revert                # Interactive revert
./optimize-samsung.sh --bloatware --rotation  # Only bloatware + rotation
./optimize-samsung.sh --updates               # Disable OS updates
./optimize-samsung.sh --updates --revert      # Re-enable OS updates
./optimize-samsung.sh --report                # Device status only
```

### Interactive Menu

When run without flags, the script shows a device-specific menu:

```
  Connected Device
  ───────────────────────────────────────────
  Model:    SM-F956U1 (TALBOT's Z Fold 6)
  Type:     Foldable
  Android:  16 (SDK 36)
  RAM:      12GB (11817MB)

  Available optimizations for SM-F956U1 (Foldable):

   1) * Rotation & Display Fixes         Auto-rotate all apps + flex mode + app continuity
   2) * Battery & Power Management       Disable app standby/auto-sleep, WiFi scan throttle
   3)   Memory Optimization              Review RAM Plus settings (12GB RAM — plenty)
   4) * Disable Bloatware                Remove Bixby, Samsung Free, AR Zone, ad services, etc.
   5) * Facebook Rotation Overrides      Force Facebook to respect device rotation
   6) * Device Status Report             Show current settings, RAM, battery, packages

  * = recommended for this device

  Selection: rec
```

## Tested Devices

| Device | Model | Android | Detected As |
|---|---|---|---|
| Galaxy Z Fold 6 | SM-F956U1 | 16 (SDK 36) | Foldable |
| Galaxy Tab S6 Lite | SM-P620 | 16 (SDK 36) | Tablet |

Should work on any Samsung Galaxy device with USB debugging enabled. Device type detection covers:
- **Foldables**: Fold, Flip (model name match)
- **Tablets**: Tab series, SM-P/SM-X model prefixes, Android tablet characteristic
- **Phones**: Everything else

## Files

| File | Platform | Purpose |
|---|---|---|
| [optimize-samsung.sh](optimize-samsung.sh) | Linux / macOS | Main bash script |
| [optimize-samsung.ps1](optimize-samsung.ps1) | Windows | Full PowerShell port |
| [optimize-samsung.bat](optimize-samsung.bat) | Windows | Batch launcher (calls .ps1 with `--flag` style args) |
| [instructions.md](instructions.md) | All | Detailed technical documentation |

> **For developers / AI-assisted development:** [instructions.md](instructions.md) contains comprehensive documentation of every optimization, what each ADB command does, troubleshooting steps, and device-specific notes. It's included specifically so that anyone modifying this software — whether with AI assistance or otherwise — has full context about the design decisions and technical details.

## Persistence After System Updates

Most optimizations survive reboots, but **Samsung OTA / One UI updates may reset some settings**:

| What | Survives reboot? | Survives OTA update? | Action needed |
|---|---|---|---|
| Settings database changes (rotation, battery, RAM Plus) | ✅ Yes | ✅ Usually | — |
| Disabled bloatware packages | ✅ Yes | ⚠️ May re-enable | Re-run `--bloatware` |
| `wm set-ignore-orientation-request false` | ✅ Yes | ❌ Often resets | Re-run `--rotation` |
| `am compat enable` per-app overrides | ✅ Yes | ❌ Often resets | Re-run `--per-app` |
| Disabled OTA agents (if used) | ✅ Yes | N/A | — |

**After a system/OTA update:** re-run `./optimize-samsung.sh --rotation --per-app --bloatware` to restore anything that was reset.

**After a major One UI upgrade:** re-run the full interactive mode or `--all` to reapply everything.

## Safety

- **No root required** — all commands use standard ADB shell
- **Disable, not uninstall** — bloatware is disabled per-user, not removed from the system partition
- **Instant revert** — `./optimize-samsung.sh --revert` undoes everything
- **Dry-run first** — `--dry-run` shows exactly what will happen before you commit
- **Non-destructive** — settings changes only; no files are modified on the device
- **OS updates are opt-in only** — never disabled unless you explicitly choose it

## After Running

One setting can't be changed via ADB — do this manually on the device:

> **Settings → Battery → Background usage limits** → toggle OFF **"Put unused apps to sleep"**

A reboot is recommended after applying optimizations.

## License

MIT
