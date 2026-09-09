import AppKit
import ApplicationServices

// Manual UI driver; coordinates are Quartz global points, never screenshot pixels.
let args = Array(CommandLine.arguments.dropFirst())
func event(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}
switch args.first {
case "windows":
    let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []).filter {
        if args.count > 1 { return ($0[kCGWindowOwnerPID as String] as? Int) == Int(args[1]) }
        return ($0[kCGWindowOwnerName as String] as? String)?.contains("Terminal") == true
    }
    let data = try! JSONSerialization.data(withJSONObject: windows, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
case "quit":
    print(NSRunningApplication(processIdentifier: Int32(args[1])!)?.terminate() ?? false)
case "ax":
    func walk(_ el: AXUIElement, _ depth: Int) {
        guard depth < 5 else { return }
        var parts: [String] = []
        for key in [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXPositionAttribute, kAXSizeAttribute] {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, key as CFString, &value) == .success { parts.append("\(key)=\(value!)") }
        }
        print(String(repeating: " ", count: depth), parts.joined(separator: " "))
        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &children) == .success {
            for child in children as? [AXUIElement] ?? [] { walk(child, depth + 1) }
        }
    }
    walk(AXUIElementCreateApplication(Int32(args[1])!), 0)
case "screens":
    for s in NSScreen.screens { print(s.frame, s.visibleFrame, s.safeAreaInsets) }
case "click":
    let p = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
    event(.mouseMoved, p); event(.leftMouseDown, p); usleep(80000); event(.leftMouseUp, p)
case "drag":
    let a = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
    let b = CGPoint(x: Double(args[3])!, y: Double(args[4])!)
    event(.mouseMoved, a); event(.leftMouseDown, a); usleep(100000)
    for i in 1...30 {
        let t = Double(i) / 30
        event(.leftMouseDragged, CGPoint(x: a.x + (b.x-a.x)*t, y: a.y + (b.y-a.y)*t)); usleep(16000)
    }
    event(.leftMouseUp, b)
case "scroll":
    event(.mouseMoved, CGPoint(x: Double(args[1])!, y: Double(args[2])!))
    CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
            wheel1: Int32(args[3])!, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
case "type":
    for char in args[1].utf16 {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        var c = char
        e.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c)
        e.post(tap: .cghidEventTap)
        usleep(3000)
    }
case "return":
    let script = NSAppleScript(source: "tell application \"System Events\" to key code 36")
    script?.executeAndReturnError(nil)
default: print("windows | screens | click x y | drag x y x y | type text | return")
}
