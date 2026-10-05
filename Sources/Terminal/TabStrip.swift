import AppKit

@MainActor
final class TabOverflowScrollView: NSScrollView {
    static func horizontalDelta(deltaX: CGFloat, deltaY: CGFloat, hasOverflow: Bool, precise: Bool) -> CGFloat {
        guard hasOverflow else { return 0 }
        let raw = abs(deltaX) > 0.01 ? deltaX : deltaY
        guard abs(raw) > 0.01 else { return 0 }
        return precise ? raw : raw * 20
    }

    static func clampedOrigin(current: CGFloat, delta: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(current + delta, 0), max(0, maximum))
    }

    override func scrollWheel(with event: NSEvent) {
        guard let documentView else { return super.scrollWheel(with: event) }
        let clipView = contentView
        let maximum = documentView.frame.width - clipView.bounds.width
        let delta = Self.horizontalDelta(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                                         hasOverflow: maximum > 0, precise: event.hasPreciseScrollingDeltas)
        guard delta != 0 else { return super.scrollWheel(with: event) }
        let origin = Self.clampedOrigin(current: clipView.bounds.minX, delta: delta, maximum: maximum)
        clipView.setBoundsOrigin(NSPoint(x: origin, y: clipView.bounds.minY))
        reflectScrolledClipView(clipView)
    }
}

@MainActor
final class TabStrip: NSView {
    var onSelect: ((UUID) -> Void)?
    var onClose: ((UUID) -> Void)?
    var onRename: ((UUID) -> Void)?
    var onNew: (() -> Void)?
    var onNewInDirectory: ((UUID) -> Void)?
    var onOpenFolder: (() -> Void)?
    var onDetach: (() -> Void)?
    var onAttach: (() -> Void)?
    var isDetached = false
    private let tabs = NSStackView()
    private let scroll = TabOverflowScrollView()
    private let addButton = NSButton()
    private let folderButton = NSButton()
    private let presentationButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tabs.orientation = .horizontal; tabs.alignment = .centerY; tabs.spacing = 5
        tabs.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        // The header must keep its full height: scrolling remains enabled, but no
        // native horizontal scroller is displayed or laid out inside the tab row.
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .allowed
        scroll.scrollerStyle = .overlay; scroll.documentView = tabs
        addSubview(scroll)
        configureButton(addButton, symbol: "plus", action: #selector(createSession))
        configureButton(folderButton, symbol: "folder.badge.plus", action: #selector(openFolder))
        configureButton(presentationButton, symbol: "rectangle.on.rectangle", action: #selector(togglePresentation))
        addButton.toolTip = "New Terminal"; folderButton.toolTip = "Open folder"
        [addButton, folderButton, presentationButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor), scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor), scroll.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -6),
            tabs.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), tabs.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            tabs.heightAnchor.constraint(equalToConstant: 32),
            addButton.trailingAnchor.constraint(equalTo: folderButton.leadingAnchor, constant: -3),
            folderButton.trailingAnchor.constraint(equalTo: presentationButton.leadingAnchor, constant: -3),
            presentationButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor), folderButton.centerYAnchor.constraint(equalTo: centerYAnchor), presentationButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 25), folderButton.widthAnchor.constraint(equalToConstant: 25), presentationButton.widthAnchor.constraint(equalToConstant: 25),
            addButton.heightAnchor.constraint(equalToConstant: 25), folderButton.heightAnchor.constraint(equalToConstant: 25), presentationButton.heightAnchor.constraint(equalToConstant: 25)
        ])
    }
    required init?(coder: NSCoder) { nil }

    var horizontalScrollerIsHidden: Bool { scroll.horizontalScroller?.isHidden ?? true }

    override func mouseDown(with event: NSEvent) {
        guard isDetached, let window else { return super.mouseDown(with: event) }
        window.performDrag(with: event)
    }

    func render(sessions: [TerminalSession], selectedID: UUID?) {
        tabs.arrangedSubviews.forEach { tabs.removeArrangedSubview($0); $0.removeFromSuperview() }
        for session in sessions {
            let item = TerminalTabItem(session: session, selected: session.id == selectedID)
            item.onSelect = { [weak self] in self?.onSelect?(session.id) }
            item.onClose = { [weak self] in self?.onClose?(session.id) }
            item.onNew = { [weak self] in self?.onNewInDirectory?(session.id) }
            item.onRename = { [weak self] in self?.onRename?(session.id) }
            tabs.addArrangedSubview(item)
        }
        presentationButton.image = NSImage(systemSymbolName: isDetached ? "arrow.down.right.and.arrow.up.left" : "rectangle.on.rectangle", accessibilityDescription: nil)
        presentationButton.toolTip = isDetached ? "Attach Terminal to the menu bar" : "Detach Terminal into a desktop window"
        layoutSubtreeIfNeeded()
        if let index = sessions.firstIndex(where: { $0.id == selectedID }) { tabs.arrangedSubviews[index].scrollToVisible(tabs.arrangedSubviews[index].bounds) }
    }
    private func configureButton(_ button: NSButton, symbol: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); button.contentTintColor = NSColor.white.withAlphaComponent(0.72)
        button.isBordered = false; button.bezelStyle = .regularSquare; button.target = self; button.action = action
    }
    @objc private func createSession() { onNew?() }
    @objc private func openFolder() { onOpenFolder?() }
    @objc private func togglePresentation() { isDetached ? onAttach?() : onDetach?() }
}

@MainActor
private final class TerminalTabItem: NSView {
    var onSelect: (() -> Void)?; var onClose: (() -> Void)?; var onRename: (() -> Void)?; var onNew: (() -> Void)?
    private let title = NSTextField(labelWithString: ""); private let close = NSButton(); private let add = NSButton()
    init(session: TerminalSession, selected: Bool) {
        super.init(frame: .zero); wantsLayer = true; layer?.cornerRadius = 7; layer?.cornerCurve = .continuous
        layer?.backgroundColor = (selected ? NSColor.white.withAlphaComponent(0.13) : .clear).cgColor
        title.stringValue = session.name; title.font = NSFont.systemFont(ofSize: 12, weight: selected ? .medium : .regular); title.textColor = NSColor.white.withAlphaComponent(selected ? 0.92 : 0.58); title.lineBreakMode = .byTruncatingTail; title.translatesAutoresizingMaskIntoConstraints = false; addSubview(title)
        add.title = "+"; add.font = NSFont.systemFont(ofSize: 14, weight: .medium); add.contentTintColor = NSColor.white.withAlphaComponent(selected ? 0.65 : 0.36); add.isBordered = false; add.target = self; add.action = #selector(newTab); add.translatesAutoresizingMaskIntoConstraints = false; addSubview(add)
        close.title = "×"; close.font = NSFont.systemFont(ofSize: 15); close.contentTintColor = NSColor.white.withAlphaComponent(selected ? 0.65 : 0.36); close.isBordered = false; close.target = self; close.action = #selector(closeTab); close.translatesAutoresizingMaskIntoConstraints = false; addSubview(close)
        let textWidth = (session.name as NSString).size(withAttributes: [.font: title.font as Any]).width
        widthAnchor.constraint(equalToConstant: min(190, max(112, ceil(textWidth) + 57))).isActive = true
        NSLayoutConstraint.activate([heightAnchor.constraint(equalToConstant: 32), title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10), title.centerYAnchor.constraint(equalTo: centerYAnchor), add.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 2), add.centerYAnchor.constraint(equalTo: centerYAnchor), add.widthAnchor.constraint(equalToConstant: 17), close.leadingAnchor.constraint(equalTo: add.trailingAnchor, constant: 1), close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5), close.centerYAnchor.constraint(equalTo: centerYAnchor), close.widthAnchor.constraint(equalToConstant: 17)])
    }
    required init?(coder: NSCoder) { nil }
    override func mouseDown(with event: NSEvent) { if event.clickCount == 2 { onRename?() } else { onSelect?() } }
    @objc private func newTab() { onNew?() }
    @objc private func closeTab() { onClose?() }
}
