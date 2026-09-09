import AppKit
import Darwin

/// Integration checks inside the actual app/PTY/event loop, including the installed release.
@MainActor
enum SmokeTest {
    struct Failure: Error { let reason: String }

    private static func require(_ condition: Bool, _ reason: String) throws {
        if !condition { throw Failure(reason: reason) }
    }

    private static func pause(_ ms: Int) async {
        try? await Task.sleep(for: .milliseconds(ms))
    }

    static func run(controller: TerminalPanelController, sessions: TerminalSessionManager) async {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/menu-smoke-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for _ in 0..<20 {
                if controller.menu.statusFrameOnScreen() != nil { break }
                await pause(100)
            }
            try require(controller.menu.isInstalled && controller.menu.isIconOnly, "icon-only status item")
            try require(controller.menu.statusFrameOnScreen() != nil && !controller.panel.isVisible, "closed launch with reachable icon")
            let original = sessions.selectedSessionID
            let one = try sessions.createSession(in: root, name: "One")
            let two = try sessions.createSession(in: URL(fileURLWithPath: "/"), name: "Two")
            if let original { sessions.closeSession(id: original) }
            let onePID = one.terminalView.process.shellPid
            let marker = root.appendingPathComponent("pwd")
            two.send("pwd > '\(marker.path)'\n")
            one.send("sleep 4; printf finished > '\(root.path)/long'\n")
            await pause(500)
            try require(try String(contentsOf: marker, encoding: .utf8) == "/\n", "independent directory/input")
            sessions.selectSession(id: one.id)
            for _ in 0..<10 {
                controller.menu.performClick()
                try require(controller.panel.isVisible, "status click opens")
                try require(controller.panel.firstResponder === one.terminalView, "keyboard focus")
                let size = one.terminalView.frame.size
                controller.menu.performClick()
                await pause(30)
                try require(!controller.panel.isVisible && one.terminalView.frame.size == size, "close preserves grid")
            }
            controller.show()
            let view = controller.contentView
            let before = one.terminalView.frame.size
            controller.panel.setContentSize(NSSize(width: 820, height: 520))
            view.layoutSubtreeIfNeeded()
            try require(one.terminalView.frame.size != before, "resize reaches SwiftTerm")
            try require(view.terminalHost.frame.minX == 12 && view.terminalHost.frame.minY == 10,
                        "external horizontal/vertical padding")
            controller.hide()
            for _ in 0..<50 {
                if FileManager.default.fileExists(atPath: root.path + "/long") { break }
                await pause(100)
            }
            try require(FileManager.default.fileExists(atPath: root.path + "/long"), "foreground command survives closing")
            try require(one.terminalView.process.shellPid == onePID && one.isRunning, "same PTY after reopen")
            sessions.renameSession(id: two.id, to: "Build")
            try require(two.name == "Build", "rename")
            sessions.closeSession(id: two.id)
            try require(sessions.sessions.count == 1 && one.isRunning, "close independent tab")
            controller.menu.remove()
            await pause(700)
            try require(controller.menu.isInstalled && controller.menu.isIconOnly, "status lifecycle recovery")
            controller.show()
            controller.hide()
            sessions.closeSession(id: one.id)
            try require(sessions.sessions.count == 1 && sessions.selectedSession?.isRunning == true, "last tab replacement")
            try FileManager.default.removeItem(at: root)
            print("Terminal menu-only smoke: PASS")
            NSApp.terminate(nil)
        } catch {
            fputs("Terminal menu-only smoke: FAIL (\(error))\n", stderr)
            controller.shutdown()
            sessions.stopAll()
            exit(EXIT_FAILURE)
        }
    }
}
