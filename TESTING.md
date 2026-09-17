# Testing — Terminal 3.0 build 6

Overall validated status: **PASS within the tested scope**.

This document contains the public-facing validation record for the stable Terminal 3.0 build 6 baseline. Only checks that were actually executed are marked PASS.

## Build and automated tests

| Check | Result | Notes |
| --- | --- | --- |
| Debug build | PASS | Swift package debug build completed successfully. |
| Release build | PASS | Release application bundle built successfully. |
| XCTest | PASS | 11 tests, 0 failures. |
| Ad-hoc signing | PASS | Built bundle passed strict `codesign` verification. |
| Release smoke test | PASS | Executed against the installed release build. |

## Functional validation

The final validation covered the following behavior:

- icon-only menu-bar presentation at launch;
- panel initially closed;
- click-to-open and click-to-close behavior;
- terminal focus after opening;
- resizable but non-movable panel behavior;
- real SwiftTerm view resizing;
- PTY grid changes after native resize;
- line wrapping and scrolling;
- input after scrolling;
- independent working directories across tabs;
- stable shell PID across repeated hide/show cycles;
- foreground process survival while the panel is hidden;
- tab selection, rename and close;
- replacement session after closing the final tab;
- folder picker cancellation behavior;
- status-item recovery;
- clean quit and restart;
- cleanup/deallocation coverage for the panel controller;
- synthetic screen-change and wake-notification handling.

A real UI regression run used mouse and keyboard events against the release application rather than relying only on programmatic view manipulation.

## Terminal geometry

Native panel resize was verified to propagate through SwiftTerm to the PTY grid. One recorded run changed the terminal from:

```text
23 × 82
```

to:

```text
28 × 93
```

The terminal padding is external to `LocalProcessTerminalView`, so resize, wrapping, scrolling and mouse coordinates continue to use the actual available terminal area.

## Session persistence

Opening, hiding and resizing the panel do not create a replacement shell session.

Validation confirmed that:

- the same session view survives show/hide cycles;
- a long-running foreground process remains active while hidden;
- switching away from and back to a tab preserves its shell process;
- multiple tabs can retain independent current working directories.

## Presentation lifecycle

Terminal 3.0 uses one menu-bar presentation model:

```text
NSStatusItem → anchored TerminalPanel → TerminalPanelView → SwiftTerm
```

The previous floating/notch presentation system is not part of the 3.0 architecture.

## Scenarios not claimed as validated

The following checks were not physically executed during the final baseline validation and are therefore **not marked PASS**:

- real hardware sleep/wake cycle;
- physical multi-monitor disconnect/reconnect;
- hardware-notch-specific behavior;
- runtime validation on every supported macOS release;
- quantitative long-duration profiling with Instruments;
- exhaustive end-to-end testing of every interactive TUI application.

Synthetic screen/wake handling and general geometry logic were tested, but those tests do not replace the physical scenarios above.

## Known defects

No requested defect remained reproducible within the verified 3.0 build 6 scope at the end of the recorded validation.

The unexecuted scenarios listed above are test-coverage limits, not known failures.
