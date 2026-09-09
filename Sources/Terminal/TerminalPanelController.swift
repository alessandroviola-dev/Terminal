import AppKit

@MainActor
final class TerminalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// One permanent status item, one anchored resizable panel. No presentation-mode state machine.
@MainActor
final class TerminalPanelController: NSObject, NSWindowDelegate {
    private let sessions: TerminalSessionManager
    let contentView = TerminalPanelView(frame: NSRect(x: 0, y: 0, width: 680, height: 438))
    let panel: TerminalPanel
    private(set) var menu: MenuBarPresentation!
    private var watchdog: Timer?
    private var lastSelectedID: UUID?
    private var stopped = false
    private var positioning = false

    init(sessions: TerminalSessionManager) {
        self.sessions = sessions
        panel = TerminalPanel(contentRect: contentView.frame, styleMask: [.borderless, .resizable],
                              backing: .buffered, defer: false)
        super.init()
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 420, height: 240)
        panel.delegate = self
        contentView.tabStrip.onSelect = { [weak self] in self?.sessions.selectSession(id: $0) }
        contentView.tabStrip.onClose = { [weak self] in self?.sessions.closeSession(id: $0) }
        contentView.tabStrip.onRename = { [weak self] in self?.rename(id: $0) }
        contentView.tabStrip.onNew = { [weak self] in self?.createSession() }
        contentView.tabStrip.onOpenFolder = { [weak self] in self?.openFolder() }
        sessions.onChange = { [weak self] in self?.syncSessions() }
        syncSessions()
        installStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(screenEnvironmentChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenEnvironmentChanged(_:)),
            name: NSWorkspace.didWakeNotification, object: nil)
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.ensureStatusItem() }
        }
    }

    private func installStatusItem() {
        menu?.remove()
        menu = MenuBarPresentation()
        menu.onToggle = { [weak self] in self?.toggle() }
    }

    func ensureStatusItem() {
        guard !stopped, menu?.isInstalled != true else { return }
        installStatusItem()
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        guard !stopped else { return }
        ensureStatusItem()
        guard positionUnderStatusItem() else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        focusTerminal()
    }

    func hide() {
        guard panel.attachedSheet == nil else { return }
        panel.makeFirstResponder(nil)
        // Do not shrink or detach SwiftTerm. Hidden jobs retain their grid and scrollback.
        panel.orderOut(nil)
    }

    /// Geometry is relative to the clicked status item's display, including negative origins.
    static func anchoredFrame(size: NSSize, status: NSRect, visible: NSRect) -> NSRect {
        let width = min(max(size.width, 1), visible.width)
        let height = min(max(size.height, 1), visible.height)
        let x = min(max(status.midX - width / 2, visible.minX), visible.maxX - width)
        let top = min(status.minY - 3, visible.maxY)
        return NSRect(x: x, y: max(visible.minY, top - height), width: width, height: height)
    }

    @discardableResult
    private func positionUnderStatusItem() -> Bool {
        guard !positioning, let status = menu.statusFrameOnScreen(),
              let screen = NSScreen.screens.first(where: { $0.frame.contains(status) }) else { return false }
        positioning = true
        defer { positioning = false }
        panel.maxSize = screen.visibleFrame.size
        panel.setFrame(Self.anchoredFrame(size: panel.frame.size, status: status, visible: screen.visibleFrame), display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        return true
    }

    @objc private func screenEnvironmentChanged(_ notification: Notification) {
        ensureStatusItem()
        // Screen/menu layout is asynchronous. Even a sheet must not strand its parent on a removed display.
        if let sheet = panel.attachedSheet {
            panel.endSheet(sheet, returnCode: .cancel)
            sheet.orderOut(nil)
        }
        panel.makeFirstResponder(nil)
        panel.orderOut(nil)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        positionUnderStatusItem()
    }

    func windowDidResize(_ notification: Notification) {
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    func windowDidResignKey(_ notification: Notification) {
        // A status-button click owns its toggle; a sheet must retain its parent panel.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.panel.isKeyWindow, !self.menu.isTracking,
                  self.panel.attachedSheet == nil else { return }
            self.hide()
        }
    }

    private func focusTerminal() {
        guard panel.isVisible, panel.isKeyWindow, panel.attachedSheet == nil,
              let terminal = sessions.selectedSession?.terminalView else { return }
        panel.makeFirstResponder(terminal)
    }

    private func syncSessions() {
        contentView.render(sessions: sessions.sessions, selectedID: sessions.selectedSessionID)
        if lastSelectedID != sessions.selectedSessionID { focusTerminal() }
        lastSelectedID = sessions.selectedSessionID
    }

    private func createSession(in directory: URL? = nil) {
        do { _ = try sessions.createSession(in: directory) }
        catch { NSAlert(error: error).beginSheetModal(for: panel) }
    }

    private func openFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = "Open in Terminal"
        picker.beginSheetModal(for: panel) { [weak self] response in
            guard let self else { return }
            if response == .OK, let folder = picker.url { self.createSession(in: folder) }
            self.focusTerminal()
        }
    }

    private func rename(id: UUID) {
        guard let session = sessions.sessions.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Terminal Session"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: session.name)
        field.frame.size = NSSize(width: 260, height: 24)
        alert.accessoryView = field
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard let self else { return }
            if response == .alertFirstButtonReturn { self.sessions.renameSession(id: id, to: field.stringValue) }
            self.focusTerminal()
        }
    }

    func shutdown() {
        stopped = true
        watchdog?.invalidate()
        watchdog = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        sessions.onChange = nil
        menu.remove()
        panel.orderOut(nil)
    }
}
