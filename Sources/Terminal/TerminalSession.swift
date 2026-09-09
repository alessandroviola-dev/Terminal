import AppKit
import SwiftTerm
import Darwin

/// A single independent SwiftTerm PTY, shell, working directory, and process.
/// Its terminal view is retained for the full lifetime of the session and is only re-parented by the UI.
@MainActor
final class TerminalSession: NSObject, LocalProcessTerminalViewDelegate {
    let id = UUID()
    let terminalView: LocalProcessTerminalView
    var name: String
    private(set) var workingDirectory: URL
    var isRunning: Bool { !stopped && terminalView.process.running }
    private var started = false
    private var stopped = false
    var onExit: (() -> Void)?
    var onWorkingDirectoryChanged: ((URL) -> Void)?

    init(directory: URL, name: String? = nil) {
        workingDirectory = directory.standardizedFileURL
        self.name = name ?? TerminalSession.defaultName(for: directory)
        terminalView = LocalProcessTerminalView(
            frame: NSRect(x: 0, y: 0, width: 680, height: 395),
            font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            options: .default
        )
        super.init()
        terminalView.nativeBackgroundColor = NSColor(calibratedWhite: 0.025, alpha: 1)
        terminalView.nativeForegroundColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        terminalView.processDelegate = self
    }

    func start() throws {
        guard !started else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workingDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue, FileManager.default.isReadableFile(atPath: workingDirectory.path) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: workingDirectory.path])
        }
        let preferred = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shell = FileManager.default.isExecutableFile(atPath: preferred) ? preferred : "/bin/zsh"
        let commandName = (shell as NSString).lastPathComponent
        terminalView.startProcess(
            executable: shell,
            args: ["-l", "-i"],
            execName: commandName,
            currentDirectory: workingDirectory.path
        )
        guard terminalView.process.running else { throw CocoaError(.executableLoad) }
        started = true
    }

    /// Used by automated checks. Regular keyboard input is handled directly by SwiftTerm.
    func send(_ text: String) {
        guard isRunning else { return }
        terminalView.process.send(data: Array(text.utf8)[...])
    }

    func stop() {
        guard isRunning else { return }
        // Interactive shells may ignore SIGTERM. Hang up both the foreground job and shell.
        guard let process = terminalView.process else { return }
        let group = tcgetpgrp(process.childfd)
        if group > 0, group != getpgrp() { kill(-group, SIGHUP) }
        if process.shellPid > 0 { kill(process.shellPid, SIGHUP) }
        process.terminate()
        stopped = true
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, let url = URL(string: directory), url.isFileURL else { return }
        let newDirectory = url.standardizedFileURL
        guard newDirectory != workingDirectory else { return }
        workingDirectory = newDirectory
        onWorkingDirectoryChanged?(newDirectory)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        stopped = true
        onExit?()
    }

    private static func defaultName(for directory: URL) -> String {
        let name = directory.lastPathComponent
        return name.isEmpty || directory.path == NSHomeDirectory() ? "~" : name
    }
}
