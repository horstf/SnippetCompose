import CoreGraphics
import Foundation

class EventTapManager {
    private let stateMachine: ComposeStateMachine
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?

    /// keyDown keyCodes that were suppressed — also suppress their matching keyUp.
    private var suppressedKeyCodes = Set<CGKeyCode>()

    init(stateMachine: ComposeStateMachine) {
        self.stateMachine = stateMachine
    }

    func start() {
        let t = Thread { [weak self] in self?.runTap() }
        t.name = "com.hypersnippet.eventtap"
        t.qualityOfService = .userInteractive
        t.start()
    }

    // MARK: - Tap setup (runs on dedicated thread)

    private func runTap() {
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        // A non-capturing closure can be used as a C function pointer.
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo = userInfo else {
                return Unmanaged.passRetained(event)
            }
            let mgr = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
            return mgr.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("[EventTap] Failed to create event tap — grant Accessibility access in System Settings.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        tapRunLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(tapRunLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }

    // MARK: - Event handling

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if the system disabled it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        // Loop guard: pass through events we synthesised ourselves
        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == SyntheticEventEmitter.marker {
            return Unmanaged.passRetained(event)
        }

        // Any mouse-down cancels composing (click-away / focus change).
        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            stateMachine.cancelIfComposing()
            return Unmanaged.passRetained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // keyUp: suppress only if we suppressed the matching keyDown
        if type == .keyUp {
            if suppressedKeyCodes.contains(keyCode) {
                suppressedKeyCodes.remove(keyCode)
                return nil
            }
            return Unmanaged.passRetained(event)
        }

        // keyDown: extract Unicode character
        var unicodeChars = [UniChar](repeating: 0, count: 4)
        var actualCount = 0
        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &actualCount,
            unicodeString: &unicodeChars
        )
        let character: Character? = actualCount > 0
            ? Character(Unicode.Scalar(unicodeChars[0]) ?? Unicode.Scalar(0))
            : nil

        let action = stateMachine.process(keyCode: keyCode, character: character)

        switch action {
        case .passThrough:
            return Unmanaged.passRetained(event)
        case .suppress:
            suppressedKeyCodes.insert(keyCode)
            return nil
        case .suppressAndEmit(let items):
            suppressedKeyCodes.insert(keyCode)
            DispatchQueue.global(qos: .userInteractive).async {
                // Let the target app finish processing the suppressed keystroke before
                // synthetic events start arriving. Electron/Chromium drops the first
                // backspace if it arrives while the app is still handling the key-down
                // that was suppressed by the tap.
                Thread.sleep(forTimeInterval: 0.015)
                for item in items {
                    switch item {
                    case .unicode(let str):
                        // Additional gap after backspaces: ensures all deletes are
                        // committed before the replacement character is inserted.
                        Thread.sleep(forTimeInterval: 0.020)
                        SyntheticEventEmitter.postUnicode(str)
                    case .backspace(let n):
                        SyntheticEventEmitter.postBackspaces(n)
                    }
                }
            }
            return nil
        }
    }
}
