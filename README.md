# Samsung Device Optimizer

An interactive ADB toolkit that detects your Samsung Galaxy device and applies safe, reversible optimizations — rotation fixes, bloatware removal, battery management, and memory tuning.

**No root required.** Everything is done through standard ADB commands and can be reverted instantly.

## Features

- **Auto-installs ADB** if not found on your system (downloads official Google platform-tools)
- **Detects your device** — identifies foldables (Fold/Flip), tablets, and phones automatically
- **Interactive menu** — shows recommended optimizations tailored to the connected device
- **Dry-run mode** — preview every command before applying
- **Fully reversible** — `--revert` undoes all changes
- **Multi-device support** — pick from connected devices or specify a serial number

## Quick Start

```bash
git clone <repo-url> && cd zfold6-mod
chmod +x optimize-samsung.sh

# Interactive — detects device, shows menu
./optimize-samsung.sh

# Or apply everything at once
./optimize-samsung.sh --all

# Preview without changing anything
./optimize-samsung.sh --dry-run
```

> Don't have ADB? The script will offer to download and install it for you, or run `./optimize-samsung.sh --install-adb`.

## What It Optimizes

| Module | What it does | Devices |
|---|---|---|
| **Rotation** | Force all apps to follow sensor rotation, enable flex mode & app continuity | All (fold-specific extras on foldables) |
| **Battery** | Disable app standby & auto-sleep, WiFi scan throttle | All |
| **Memory** | Disable RAM Plus to stop swap thrashing | ≤4GB RAM devices |
| **Bloatware** | Disable Bixby, Samsung Free, AR Zone, Game Optimizer, ad services (16+ packages) | All |
| **Per-App Rotation** | Compat framework overrides for Facebook and other stubborn apps | Foldables & tablets |

## Usage

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

  -h, --help      Show help
```

### Examples

```bash
./optimize-samsung.sh                         # Interactive menu
./optimize-samsung.sh --all                   # Apply all, auto-detect device
./optimize-samsung.sh --all RFCX61GYT3Y      # Apply all to specific device
./optimize-samsung.sh --dry-run               # Interactive preview
./optimize-samsung.sh --revert                # Interactive revert
./optimize-samsung.sh --bloatware --rotation  # Only bloatware + rotation
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

| File | Purpose |
|---|---|
| [optimize-samsung.sh](optimize-samsung.sh) | Main script — run this |
| [instructions.md](instructions.md) | Detailed documentation — what each setting does, troubleshooting, manual steps |

## Safety

- **No root required** — all commands use standard ADB shell
- **Disable, not uninstall** — bloatware is disabled per-user, not removed from the system partition
- **Instant revert** — `./optimize-samsung.sh --revert` undoes everything
- **Dry-run first** — `--dry-run` shows exactly what will happen before you commit
- **Non-destructive** — settings changes only; no files are modified on the device

## After Running

One setting can't be changed via ADB — do this manually on the device:

> **Settings → Battery → Background usage limits** → toggle OFF **"Put unused apps to sleep"**

A reboot is recommended after applying optimizations.

## License

MIT
