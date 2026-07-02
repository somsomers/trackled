# Trackled

A lightweight macOS menu-bar app that tracks how much time you spend in each
application and window, entirely on your machine.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Per-app & per-window tracking** — samples the frontmost application and its
  focused window title, aggregating time by day.
- **Statistics window** — pick any date and see a ranked breakdown with progress
  bars. App cards are collapsible (collapsed by default).
- **Weekly trend** — a bar chart of the last 7 days for any individual app.
- **App info** — bundle identifier, version, tracked window count, and full path,
  with a *Show in Finder* shortcut.
- **Light / dark / system theme** switch.
- **Configurable** — sampling interval and idle timeout.
- **Launch at login** toggle.
- **Private by design** — all data stays in
  `~/Library/Application Support/Trackled/` as plain JSON. Nothing leaves your Mac.

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ toolchain (Xcode 15+ or the Swift toolchain) to build from source

## Install

Build the `.app` bundle and copy it into `~/Applications`:

```sh
git clone https://github.com/somsomers/trackled.git
cd trackled
./make_app.sh        # produces build/Trackled.app
```

Or, if you have [`just`](https://github.com/casey/just):

```sh
just deploy          # builds, bundles, and installs to ~/Applications
```

Then launch `Trackled.app`. It runs in the menu bar (no Dock icon).

### Accessibility permission

To read window titles, Trackled needs the Accessibility permission. On first run
macOS will prompt you; otherwise grant it manually in
**System Settings → Privacy & Security → Accessibility**. Without it, tracking
still works per application, just without window titles.

## Usage

Click the clock icon in the menu bar:

- **Statistics…** — open the stats window.
- **Settings…** (⌘,) — sampling interval, idle timeout, and launch-at-login.
- **Quit** — stop tracking and exit.

## Configuration

| Setting | Description | Default |
|---|---|---|
| Sampling interval | How often the active window is checked | 1 sec |
| Idle timeout | Stop tracking after this long with no input | 60 sec |
| Launch at login | Start Trackled automatically at login | off |

## Development

```sh
swift build          # debug build
swift run            # run from the terminal (login-item toggle needs the bundle)
```

Source layout (`Sources/app-tracker/`):

- `AppTrackerApp.swift` — app entry point, menu bar, window controllers
- `Tracker.swift` — sampling engine (Accessibility + workspace APIs)
- `Storage.swift` — per-day JSON storage and aggregation
- `StatsView.swift` — statistics UI, weekly trend, app info
- `Settings.swift` — settings, login item, preferences

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Released under the [MIT License](LICENSE). © 2026 somsomers.
