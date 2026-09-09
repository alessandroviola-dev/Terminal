import AppKit

/// Central in-memory owner for all PTYs. It deliberately has no window knowledge.
@MainActor
final class TerminalSessionManager {
    private(set) var sessions: [TerminalSession] = []
    private(set) var selectedSessionID: UUID?
    var onChange: (() -> Void)?

    var selectedSession: TerminalSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    @discardableResult
    func createSession(in directory: URL? = nil, name: String? = nil) throws -> TerminalSession {
        let directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
        let session = TerminalSession(directory: directory, name: name)
        session.onExit = { [weak self, weak session] in
            guard let self, let session else { return }
            self.sessionDidChange(session)
        }
        session.onWorkingDirectoryChanged = { [weak self, weak session] _ in
            guard let self, let session else { return }
            self.sessionDidChange(session)
        }
        try session.start()
        sessions.append(session)
        selectedSessionID = session.id
        notifyChange()
        return session
    }

    func selectSession(id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        guard selectedSessionID != id else { return }
        selectedSessionID = id
        notifyChange()
    }

    func renameSession(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let session = sessions.first(where: { $0.id == id }) else { return }
        session.name = trimmed
        notifyChange()
    }

    func closeSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let closing = sessions.remove(at: index)
        closing.stop()

        if sessions.isEmpty {
            // Keep the island useful even when its final tab is closed.
            do {
                let replacement = try createSession()
                selectedSessionID = replacement.id
            } catch {
                selectedSessionID = nil
                notifyChange()
            }
            return
        }

        if selectedSessionID == id {
            selectedSessionID = sessions[max(0, index - 1)].id
        }
        notifyChange()
    }

    func stopAll() {
        sessions.forEach { $0.stop() }
        sessions.removeAll()
        selectedSessionID = nil
        notifyChange()
    }

    private func sessionDidChange(_ session: TerminalSession) {
        guard sessions.contains(where: { $0.id == session.id }) else { return }
        notifyChange()
    }

    private func notifyChange() { onChange?() }
}
