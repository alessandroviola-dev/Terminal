import AppKit

/// Permanent, icon-only entry point. A drag is ignored, never converted into a window move.
@MainActor
final class MenuBarPresentation: NSObject {
    var onToggle: (() -> Void)?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var removed = false
    private(set) var isTracking = false

    override init() {
        super.init()
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Terminal")!
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 16)
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "Terminal"
        button.setAccessibilityLabel("Terminal")
        button.target = self
        button.action = #selector(trackClick(_:))
        button.sendAction(on: [.leftMouseDown])
        statusItem.behavior = [] // Do not allow Command-drag removal from the menu bar.
        statusItem.isVisible = true
    }

    var isInstalled: Bool {
        !removed && statusItem.isVisible && statusItem.button?.target === self
    }

    var isIconOnly: Bool {
        statusItem.button?.title == "" && statusItem.button?.image?.isTemplate == true
    }

    func statusFrameOnScreen() -> NSRect? {
        guard isInstalled, let button = statusItem.button, let window = button.window else { return nil }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard frame.width > 0, frame.height > 0, NSScreen.screens.contains(where: { $0.frame.contains(frame) }) else { return nil }
        return frame
    }

    func remove() {
        guard !removed else { return }
        removed = true
        statusItem.button?.target = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func performClick() { statusItem.button?.performClick(nil) }

    @objc private func trackClick(_ sender: Any?) {
        guard NSApp.currentEvent?.type == .leftMouseDown else { onToggle?(); return }
        let start = NSEvent.mouseLocation
        var moved = false
        isTracking = true
        defer { isTracking = false }
        while let event = NSApp.nextEvent(matching: [.leftMouseDragged, .leftMouseUp],
                                          until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            let point = NSEvent.mouseLocation
            if hypot(point.x - start.x, point.y - start.y) > 3 { moved = true }
            if event.type == .leftMouseUp {
                if !moved { onToggle?() }
                return
            }
        }
    }
}
