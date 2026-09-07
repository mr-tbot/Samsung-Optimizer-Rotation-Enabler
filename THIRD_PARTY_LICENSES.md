# Third-party software & attributions

This project is MIT-licensed (see [LICENSE](LICENSE)). Its own code is
original Bash, PowerShell and Batch — no bundled third-party source, no
binaries, nothing forked or redistributed. The repository ships glue code that
drives Android Debug Bridge over its public interface.

## Required runtime dependency

### Android Debug Bridge (adb) / Android SDK platform-tools
- **Project:** <https://developer.android.com/tools/adb> · <https://developer.android.com/studio/releases/platform-tools>
- **License:** adb's source is Apache-2.0 within AOSP; the prebuilt platform-tools bundle Google serves from `dl.google.com` is governed by the [Android Software Development Kit License Agreement](https://developer.android.com/studio/terms).
- **Role:** every optimization is an `adb shell` subprocess call (`settings put`, `pm disable-user`, `wm`, `cmd`). No adb source or binary is committed to or served from this repository. When adb is absent, the scripts download the official platform-tools bundle onto the user's own machine — that download, and its acceptance of Google's SDK terms, happens on the user's side.

## Trademarks
"Samsung", "Galaxy" and "Bixby" are trademarks of Samsung Electronics Co.,
Ltd.; "Android" and "Google" are trademarks of Google LLC. This project is an
independent third-party tool, not endorsed by or affiliated with Samsung or
Google.
