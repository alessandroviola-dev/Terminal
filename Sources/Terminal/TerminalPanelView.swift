import AppKit
import SwiftTerm

/// Only the terminal presentation. Hiding the panel preserves this view's size and PTY grid.
@MainActor
final class TerminalPanelView: NSVisualEffectView {
    let tabStrip = TabStrip(frame: .zero)
    let terminalHost = NSView(frame: .zero)
    private weak var displayedTerminal: LocalProcessTerminalView?
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let headerHeight: CGFloat = 39

    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor

        let divider = NSView(frame: .zero)
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.09).cgColor
        for view in [tabStrip, divider, terminalHost] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // Insets belong OUTSIDE SwiftTerm: its frame is the actual available text/scroll area.
        // SwiftTerm therefore calculates rows, columns, wrapping and mouse coordinates normally.
        NSLayoutConstraint.activate([
            tabStrip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            tabStrip.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            tabStrip.topAnchor.constraint(equalTo: topAnchor),
            tabStrip.heightAnchor.constraint(equalToConstant: Self.headerHeight - 1),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.topAnchor.constraint(equalTo: tabStrip.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            terminalHost.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            terminalHost.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            terminalHost.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: Self.verticalPadding),
            terminalHost.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.verticalPadding)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func render(sessions: [TerminalSession], selectedID: UUID?) {
        tabStrip.render(sessions: sessions, selectedID: selectedID)
        let selected = sessions.first { $0.id == selectedID }
        guard displayedTerminal !== selected?.terminalView else { return }
        displayedTerminal?.removeFromSuperview()
        displayedTerminal = selected?.terminalView
        guard let terminal = displayedTerminal else { return }
        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminalHost.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: terminalHost.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: terminalHost.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: terminalHost.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: terminalHost.bottomAnchor)
        ])
    }
}
