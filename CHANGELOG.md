# Changelog

All notable public-facing changes to Terminal are documented here.

## Unreleased

- Public-release preparation: documentation, validation record, security policy and CI metadata.

## 3.0 — build 6

Stable menu-bar baseline.

### Changed

- Replaced the previous floating/notch presentation concept with a single anchored menu-bar panel.
- Reduced the menu-bar item to an icon-only status item.
- Kept the panel resizable while intentionally preventing free desktop movement.
- Added real external padding around the SwiftTerm view.
- Simplified presentation state and lifecycle handling.

### Retained

- Real local PTY-backed shell sessions.
- Multiple independent tabs.
- Per-session working directories and process state.
- Rename and close behavior for tabs.
- Session persistence while the panel is hidden.
- Folder-based session creation.

### Validation

- Debug and release builds passed.
- 11 XCTest tests passed with zero failures.
- Release smoke test passed.
- Real mouse/keyboard UI regression passed.
- Native resize, PTY grid propagation, wrapping, scrolling and long-running process persistence were validated.

See `TESTING.md` for the exact validation scope.
