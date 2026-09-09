import AppKit
import XCTest
@testable import Terminal

final class LifecycleTests: XCTestCase {
    @MainActor
    func testControllerReleasesAfterShutdown() {
        weak var released: TerminalPanelController?
        autoreleasepool {
            let controller = TerminalPanelController(sessions: TerminalSessionManager())
            released = controller
            controller.shutdown()
        }
        XCTAssertNil(released)
    }

    @MainActor
    func testScreenAndWakeNotificationsClosePanelWithoutLosingStatusItem() async throws {
        let controller = TerminalPanelController(sessions: TerminalSessionManager())
        defer { controller.shutdown() }
        controller.panel.orderFrontRegardless()
        let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                            styleMask: [.titled], backing: .buffered, defer: false)
        controller.panel.beginSheet(sheet, completionHandler: nil)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(controller.panel.isVisible)
        XCTAssertFalse(sheet.isVisible)
        XCTAssertTrue(controller.menu.isInstalled)
        controller.panel.orderFrontRegardless()
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertFalse(controller.panel.isVisible)
        XCTAssertTrue(controller.menu.isInstalled)
    }

    @MainActor
    func testIconOnlyAndClosedLaunch() {
        _ = NSApplication.shared
        let manager = TerminalSessionManager()
        let controller = TerminalPanelController(sessions: manager)
        defer { controller.shutdown() }
        XCTAssertTrue(controller.menu.isInstalled)
        XCTAssertTrue(controller.menu.isIconOnly)
        XCTAssertFalse(controller.panel.isVisible)
        XCTAssertFalse(controller.panel.isMovable)
        XCTAssertFalse(controller.panel.isMovableByWindowBackground)
        XCTAssertTrue(controller.panel.styleMask.contains(.resizable))
    }

    @MainActor
    func testStatusItemRecoveryAndShutdown() {
        let controller = TerminalPanelController(sessions: TerminalSessionManager())
        let old = controller.menu
        old?.remove()
        controller.ensureStatusItem()
        XCTAssertTrue(controller.menu.isInstalled)
        XCTAssertFalse(controller.menu === old)
        controller.shutdown()
        controller.ensureStatusItem()
        XCTAssertFalse(controller.menu.isInstalled)
        XCTAssertFalse(controller.panel.isVisible)
    }

    @MainActor
    func testPaddingResizeAndHiddenGrid() throws {
        let manager = TerminalSessionManager()
        let session = try manager.createSession()
        let controller = TerminalPanelController(sessions: manager)
        defer { controller.shutdown(); manager.stopAll() }
        for size in [NSSize(width: 680, height: 438), NSSize(width: 900, height: 600), NSSize(width: 420, height: 240)] {
            controller.panel.setContentSize(size)
            controller.contentView.layoutSubtreeIfNeeded()
            let frame = controller.contentView.terminalHost.frame
            XCTAssertEqual(frame.minX, 12)
            XCTAssertEqual(frame.minY, 10)
            XCTAssertEqual(size.width - frame.maxX, 12)
            XCTAssertEqual(size.height - frame.maxY, 49) // 39pt tabs/divider + 10pt padding
            XCTAssertEqual(session.terminalView.frame.size, NSSize(width: size.width - 24, height: size.height - 59))
            let terminalSize = session.terminalView.frame.size
            controller.hide()
            controller.contentView.layoutSubtreeIfNeeded()
            XCTAssertEqual(session.terminalView.frame.size, terminalSize)
        }
    }

    @MainActor
    func testHiddenSessionChangesDoNotReopenPanel() async throws {
        let manager = TerminalSessionManager()
        let session = try manager.createSession()
        let controller = TerminalPanelController(sessions: manager)
        defer { controller.shutdown(); manager.stopAll() }
        manager.renameSession(id: session.id, to: "Renamed")
        _ = try manager.createSession()
        session.send("exit\n")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(controller.panel.isVisible)
    }

    @MainActor
    func testAnchorOnNegativeCoordinateDisplay() {
        let visible = NSRect(x: -1920, y: -100, width: 1920, height: 1050)
        let status = NSRect(x: -90, y: 950, width: 24, height: 24)
        let frame = TerminalPanelController.anchoredFrame(size: NSSize(width: 680, height: 438), status: status, visible: visible)
        XCTAssertTrue(visible.contains(frame))
        XCTAssertEqual(frame.maxY, status.minY - 3)
        XCTAssertEqual(frame.maxX, 0)
    }

    @MainActor
    func testOversizePanelFitsSmallDisplay() {
        let visible = NSRect(x: 0, y: 0, width: 640, height: 400)
        let status = NSRect(x: 500, y: 400, width: 24, height: 24)
        let frame = TerminalPanelController.anchoredFrame(size: NSSize(width: 900, height: 600), status: status, visible: visible)
        XCTAssertTrue(visible.contains(frame))
    }

    @MainActor
    func testSessionsRemainIndependentAndLastCloseReplacesShell() async throws {
        let manager = TerminalSessionManager()
        defer { manager.stopAll() }
        let first = try manager.createSession()
        let second = try manager.createSession(in: URL(fileURLWithPath: "/"))
        XCTAssertNotEqual(first.terminalView.process.shellPid, second.terminalView.process.shellPid)
        manager.selectSession(id: first.id)
        manager.closeSession(id: second.id)
        XCTAssertEqual(manager.selectedSessionID, first.id)
        XCTAssertTrue(first.isRunning)
        manager.closeSession(id: first.id)
        XCTAssertEqual(manager.sessions.count, 1)
        XCTAssertNotEqual(manager.selectedSessionID, first.id)
        XCTAssertTrue(try XCTUnwrap(manager.selectedSession).isRunning)
        try await Task.sleep(for: .milliseconds(300))
    }

    @MainActor
    func testInvalidDirectoryDoesNotCreateBrokenSession() {
        let manager = TerminalSessionManager()
        XCTAssertThrowsError(try manager.createSession(in: URL(fileURLWithPath: "/missing-\(UUID())")))
        XCTAssertTrue(manager.sessions.isEmpty)
        XCTAssertNil(manager.selectedSessionID)
    }

    @MainActor
    func testShellExitKeepsOtherSessions() async throws {
        let manager = TerminalSessionManager()
        defer { manager.stopAll() }
        let first = try manager.createSession()
        let second = try manager.createSession()
        first.send("exit\n")
        for _ in 0..<40 {
            if !first.isRunning { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(first.isRunning)
        XCTAssertTrue(second.isRunning)
        XCTAssertEqual(manager.sessions.count, 2)
        XCTAssertEqual(manager.selectedSessionID, second.id)
    }
}
