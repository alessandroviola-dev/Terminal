# Terminal

[![CI](https://github.com/alessandroviola-dev/Terminal/actions/workflows/ci.yml/badge.svg)](https://github.com/alessandroviola-dev/Terminal/actions/workflows/ci.yml)

A compact native macOS terminal that lives in the menu bar.

Terminal keeps real shell sessions close at hand without requiring a traditional terminal window to remain open. Click the menu-bar icon to reveal the terminal panel, work in one or more tabs, then hide it again without interrupting the running shell processes.

Current baseline: **Terminal 3.0 (build 6)**.

## What it does

- Runs real local shell sessions through a PTY.
- Lives as a macOS menu-bar app with no Dock icon.
- Opens and closes from a single menu-bar icon.
- Keeps shell processes alive while the panel is hidden.
- Supports multiple independent terminal tabs.
- Preserves each tab's process, PID and working directory.
- Supports tab selection, rename and close.
- Can create a terminal session from a selected folder.
- Provides a native resizable panel anchored to the menu bar.
- Keeps terminal geometry synchronized with the actual SwiftTerm view size.

Terminal is deliberately focused. It is not a shell replacement, remote terminal service, command launcher or terminal multiplexer. It is a lightweight macOS presentation layer around normal local terminal sessions.

## Interface

At launch Terminal creates a single icon-only `NSStatusItem` and starts with the panel closed.

- First click: opens the panel and focuses the active terminal.
- Second click: hides the panel.
- Hiding the panel does not terminate the shell.
- The panel can be resized but is intentionally not freely movable.
- The panel stays anchored to the active menu-bar item and constrained to the visible screen area.

The current 3.0 design intentionally removed the earlier floating/notch concept. There is no floating island, snap system, dock/undock state or alternate desktop presentation mode.

## Tabs and sessions

Each tab owns an independent `TerminalSession` backed by SwiftTerm and a local PTY.

A session retains its shell process while the application panel is hidden or while another tab is selected. Closing the final tab creates a replacement session so the app never enters an unusable no-session state.

The tab strip supports:

- independent sessions;
- selection;
- rename;
- close;
- horizontal scrolling when needed.

## Architecture

```text
AppDelegate
  ├─ TerminalSessionManager
  │    └─ TerminalSession → SwiftTerm / PTY
  │
  └─ TerminalPanelController
       ├─ MenuBarPresentation → NSStatusItem
       └─ TerminalPanel
            └─ TerminalPanelView
                 ├─ TabStrip
                 └─ SwiftTerm host
```

The presentation layer does not recreate terminal processes during ordinary show/hide or resize operations.

## Technology

- Swift
- AppKit
- Swift Package Manager
- SwiftTerm
- macOS 14 or later
- Apple Silicon is the currently validated target

The exact SwiftTerm revision used by the validated baseline is recorded in `Package.resolved`.

## Download

For normal installation, download the latest compiled `Terminal-vX.Y.Z-macOS.zip` from [GitHub Releases](https://github.com/alessandroviola-dev/Terminal/releases).

The compiled app does **not** require Xcode, Swift, Homebrew, or Command Line Tools on the destination Mac. Source builds are only for developers.

## Installation

1. Download the latest `Terminal-vX.Y.Z-macOS.zip` from [GitHub Releases](https://github.com/alessandroviola-dev/Terminal/releases).
2. Extract it to obtain `Terminal.app`.
3. Drag `Terminal.app` to `/Applications`.
4. Open Terminal.

The current builds are ad-hoc signed and are not yet Developer ID notarized. If Gatekeeper blocks the first launch, control-click the app, choose **Open**, then confirm **Open**; alternatively approve it in **System Settings → Privacy & Security**. Do not disable Gatekeeper globally.

## Requirements

The following are for source builds only:

- macOS 14 or later
- Swift 6.2 or later
- Xcode or an appropriate macOS Swift development environment

## Build from source (developers)

Clone the repository and build the application bundle:

```bash
git clone https://github.com/alessandroviola-dev/Terminal.git
cd Terminal
./Scripts/build-app.sh
```

The script creates a local `Terminal.app`. To create the arm64 release bundle and source-free ZIP used by CI, run:

```bash
./Scripts/build-release.sh
```

Both local bundles are ad-hoc signed and verified with `codesign`.

To run the Swift package directly during development:

```bash
swift build
swift run Terminal
```

## Tests

```bash
swift test
```

The validated 3.0 build 6 baseline completed:

- debug build: PASS;
- release build: PASS;
- 11 XCTest tests: PASS;
- release smoke test: PASS;
- real PTY interaction: PASS;
- repeated show/hide: PASS;
- native resize with terminal grid update: PASS;
- tab/session persistence: PASS;
- foreground-process persistence while hidden: PASS;
- real mouse/keyboard UI validation: PASS.

See [`TESTING.md`](TESTING.md) for the validation scope and the scenarios that remain intentionally unclaimed.

## Privacy

Terminal is a local terminal application.

It does not implement:

- telemetry;
- analytics;
- advertising;
- accounts;
- cloud sync;
- an application backend;
- remote command execution of its own.

Commands executed inside a terminal session can of course access the network or user files according to the command itself and the user's macOS permissions. Terminal does not alter that normal shell behavior.

## Security model

Terminal launches normal local shell processes with the privileges of the current macOS user. It does not attempt to sandbox, inspect or restrict commands entered by the user.

Security issues in Terminal itself should be reported privately; see [`SECURITY.md`](SECURITY.md).

## Project structure

```text
Terminal/
├── .github/workflows/ci.yml
├── .github/workflows/release-artifact.yml
├── Package.swift
├── Package.resolved
├── Resources/
│   └── Info.plist
├── Sources/Terminal/
├── Tests/TerminalTests/
├── Scripts/
│   ├── build-app.sh
│   ├── audit-ui.swift
│   └── audit-ui-test.py
├── README.md
├── TESTING.md
├── CHANGELOG.md
├── SECURITY.md
└── LICENSE
```

## Current limitations

The stable baseline has not been claimed as physically validated for every environment. In particular, the final validation did not include:

- a real hardware sleep/wake cycle;
- physical multi-monitor disconnect/reconnect;
- testing on every supported macOS release;
- long-duration Instruments profiling;
- exhaustive end-to-end validation of every interactive full-screen TUI.

These are coverage limits, not known defects.

## Distribution status

Terminal produces an ad-hoc-signed downloadable ZIP through GitHub Actions. Version tags matching the app version (for example `v3.0`) publish the compiled ZIP to **GitHub Releases** automatically.

A Developer ID-signed/notarized binary, stapling, and a DMG can be added later without changing the application core.

## License

Terminal is **source-available under the MIT License with the Commons Clause License Condition v1.0**.

You may use, study, modify and redistribute the software under the license terms, but you may not sell Terminal itself or offer a substantially equivalent paid product or service whose value derives substantially from Terminal's functionality.

Because of the Commons Clause restriction, Terminal should not be described as OSI-approved open-source software.

Copyright © 2026 Alessandro Viola. See [`LICENSE`](LICENSE) for the complete terms.
