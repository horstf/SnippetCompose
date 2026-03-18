import AppKit
import ApplicationServices

enum CursorPositionProvider {

    /// Screen-coordinate rect of the insertion caret in the frontmost AX-aware app.
    static func caretRect() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef
        ) == .success, let focusedRef else { return nil }

        let focused = focusedRef as! AXUIElement

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused, kAXSelectedTextRangeAttribute as CFString, &rangeRef
        ) == .success, let rangeRef else { return nil }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRef,
            &boundsRef
        ) == .success, let boundsRef else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    /// Returns the point for `NSWindow.setFrameTopLeftPoint(_:)` so the panel
    /// sits just below the caret, anchored at its top-left corner.
    /// Returns nil if the caret position cannot be determined (e.g. Electron apps
    /// that don't implement kAXBoundsForRangeParameterizedAttribute) — callers
    /// should suppress the panel rather than fall back to an arbitrary position.
    static func topLeftBelowCaret(gap: CGFloat = 4) -> NSPoint? {
        guard let rect = caretRect() else { return nil }
        // AX coordinates: origin top-left, y increases downward.
        // NSScreen coordinates: origin bottom-left of primary screen, y increases upward.
        let screenHeight = NSScreen.main?.frame.height ?? 0
        // "Top" of our panel in screen coords = just below caret bottom
        let topY = screenHeight - rect.maxY - gap
        return NSPoint(x: rect.minX, y: topY)
    }
}
