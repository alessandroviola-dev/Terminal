import AppKit

@MainActor
final class TabStrip: NSView {
    var onSelect: ((UUID) -> Void)?
    var onClose: ((UUID) -> Void)?
    var onRename: ((UUID) -> Void)?
    var onNew: (() -> Void)?
    var onOpenFolder: (() -> Void)?
    private let tabs = NSStackView()
    private let scroll = NSScrollView()
    private let addButton = NSButton()
    private let folderButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tabs.orientation = .horizontal
        tabs.alignment = .centerY
        tabs.spacing = 5
        tabs.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.documentView = tabs
        addSubview(scroll)

        configureButton(addButton, symbol: "plus", action: #selector(createSession))
        configureButton(folderButton, symbol: "folder.badge.plus", action: #selector(openFolder))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)
        addSubview(folderButton)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -6),
            tabs.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            tabs.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            tabs.heightAnchor.constraint(equalToConstant: 38),
            addButton.trailingAnchor.constraint(equalTo: folderButton.leadingAnchor, constant: -3),
            folderButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            folderButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 25),
            addButton.heightAnchor.constraint(equalToConstant: 25),
            folderButton.widthAnchor.constraint(equalToConstant: 25),
            folderButton.heightAnchor.constraint(equalToConstant: 25)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func render(sessions: [TerminalSession], selectedID: UUID?) {
        tabs.arrangedSubviews.forEach { tabs.removeArrangedSubview($0); $0.removeFromSuperview() }
        for session in sessions {
            let item = TerminalTabItem(session: session, selected: session.id == selectedID)
            item.onSelect = { [weak self] in self?.onSelect?(session.id) }
            item.onClose = { [weak self] in self?.onClose?(session.id) }
            item.onRename = { [weak self] in self?.onRename?(session.id) }
            tabs.addArrangedSubview(item)
        }
        layoutSubtreeIfNeeded()
        if let index = sessions.firstIndex(where: { $0.id == selectedID }) {
            tabs.arrangedSubviews[index].scrollToVisible(tabs.arrangedSubviews[index].bounds)
        }
    }

    private func configureButton(_ button: NSButton, symbol: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.contentTintColor = NSColor.white.withAlphaComponent(0.72)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.target = self
        button.action = action
    }

    @objc private func createSession() { onNew?() }
    @objc private func openFolder() { onOpenFolder?() }
}

@MainActor
private final class TerminalTabItem: NSView {
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?
    var onRename: (() -> Void)?
    private let title = NSTextField(labelWithString: "")
    private let close = NSButton()
    private var widthConstraint: NSLayoutConstraint?

    init(session: TerminalSession, selected: Bool) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = (selected ? NSColor.white.withAlphaComponent(0.13) : .clear).cgColor

        title.stringValue = session.name
        title.font = NSFont.systemFont(ofSize: 12, weight: selected ? .medium : .regular)
        title.textColor = NSColor.white.withAlphaComponent(selected ? 0.92 : 0.58)
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        close.title = "×"
        close.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        close.contentTintColor = NSColor.white.withAlphaComponent(selected ? 0.65 : 0.36)
        close.isBordered = false
        close.target = self
        close.action = #selector(closeTab)
        close.translatesAutoresizingMaskIntoConstraints = false
        addSubview(close)

        let textWidth = (session.name as NSString).size(withAttributes: [.font: title.font as Any]).width
        widthConstraint = widthAnchor.constraint(equalToConstant: min(172, max(88, ceil(textWidth) + 35)))
        widthConstraint?.isActive = true
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 3),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 17)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onRename?() } else { onSelect?() }
    }

    @objc private func closeTab() { onClose?() }
}

