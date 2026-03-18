import CoreGraphics
import Foundation

enum SyntheticEventEmitter {
    /// Marker stamped on every synthetic event so the tap callback can ignore them.
    static let marker: Int64 = 0x48595045  // "HYPE"

    /// CGEventSource with the marker baked in as userData.
    private static let source: CGEventSource? = {
        let s = CGEventSource(stateID: .hidSystemState)
        s?.userData = marker
        return s
    }()

    static func postUnicode(_ string: String) {
        guard !string.isEmpty else { return }
        let utf16 = Array(string.utf16)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            down.post(tap: .cgSessionEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            up.post(tap: .cgSessionEventTap)
        }
    }

    static func postBackspaces(_ count: Int) {
        for i in 0..<count {
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true) {
                down.post(tap: .cgSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) {
                up.post(tap: .cgSessionEventTap)
            }
            // Small inter-event gap prevents Electron/Chromium from coalescing repeated
            // backspace events into fewer actual deletions.
            if i < count - 1 {
                Thread.sleep(forTimeInterval: 0.004)
            }
        }
    }
}
