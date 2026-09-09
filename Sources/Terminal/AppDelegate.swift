import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let smokeTest: Bool
    private let sessionManager = TerminalSessionManager()
    private var controller: TerminalPanelController?

    init(smokeTest: Bool) { self.smokeTest = smokeTest }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        // One-time migration only: no code reads or restores the old desktop presentation.
        UserDefaults.standard.removeObject(forKey: "floatingFrame")
        UserDefaults.standard.removeObject(forKey: "presentationMode")
        do {
            _ = try sessionManager.createSession()
            let controller = TerminalPanelController(sessions: sessionManager)
            self.controller = controller
            // The status item is installed synchronously; the terminal stays closed at launch.
            if smokeTest {
                Task { await SmokeTest.run(controller: controller, sessions: sessionManager) }
            }
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
        }
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Terminal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
        sessionManager.stopAll()
    }
}
