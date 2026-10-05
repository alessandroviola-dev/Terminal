# Testing — Terminal 3.1 build 7

Overall validated status: **PASS within the tested scope**.

## Build and automated tests

| Check | Result | Notes |
| --- | --- | --- |
| `swift test` | PASS | 16 XCTest tests, 0 failures. |
| Debug build | PASS | `swift build` completed successfully. |
| Release build | PASS | `swift build -c release` completed successfully. |
| Local application build | PASS | `./Scripts/build-app.sh` completed successfully. |
| Ad-hoc signing | PASS | `codesign --verify --strict Terminal.app` passed. |
| Diff check | PASS | `git diff --check` passed. |

## Functional validation

Manual UI acceptance was completed against the local release application for:

- icon-only menu-bar presentation at launch and menu-bar mode as the default;
- panel open/hide and terminal focus;
- detached desktop-window mode;
- moving and resizing the detached window;
- persistence when the detached window loses focus;
- reattach to menu-bar mode;
- session, PTY, working-directory, selected-tab and scrollback persistence through detach/reattach;
- tab selection, rename and close;
- replacement session after closing the final tab;
- per-tab `+` creation in the source tab's current working directory;
- folder picker behavior;
- stable full-height tabs with many tabs;
- horizontal overflow without a visible scrollbar taking vertical space;
- selected-tab automatic reveal;
- trackpad horizontal tab scrolling;
- mouse-wheel vertical-to-horizontal tab scrolling;
- SwiftTerm resize and focus behavior.

Automated tests additionally cover presentation-mode transitions, session identity preservation, stable tab height, hidden scrollbars, wheel delta mapping and scroll clamping.

## Terminal geometry

Native panel resize propagates through SwiftTerm to the PTY grid. Terminal padding is external to `LocalProcessTerminalView`, so resize, wrapping, scrolling and mouse coordinates continue to use the actual available terminal area.

## Session persistence

Opening, hiding, resizing, switching tabs and changing presentation mode do not create replacement shell sessions. `TerminalSessionManager` remains the sole owner of live sessions and PTYs.

## Scenarios not claimed as validated

The following checks remain outside this validation record:

- real hardware sleep/wake cycle;
- physical multi-monitor disconnect/reconnect;
- runtime validation on every supported macOS release;
- quantitative long-duration profiling with Instruments;
- exhaustive end-to-end validation of every interactive full-screen TUI application.

These are test-coverage limits, not known failures.
