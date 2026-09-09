import AppKit

let app = NSApplication.shared
let delegate = AppDelegate(smokeTest: CommandLine.arguments.contains("--smoke-test"))
app.delegate = delegate
app.setActivationPolicy(.accessory) // A menu-bar-only accessory app, without a Dock icon.
app.run()
