import Foundation
import Combine
import CoreGraphics

enum TapState: Equatable {
    case idle
    case composing
}

enum EventTapAction {
    case passThrough
    case suppress
    case suppressAndEmit([EmitItem])
}

enum EmitItem {
    case unicode(String)
    case backspace(Int)
}

struct ComposeSuggestion: Identifiable {
    let id = UUID()
    let next: String    // character to type next
    let result: String  // unicode symbol it produces
}

class ComposeStateMachine: ObservableObject {
    // UI state — main thread only
    @Published private(set) var uiState: TapState = .idle
    @Published private(set) var uiBuffer: String = ""
    @Published private(set) var suggestions: [ComposeSuggestion] = []
    @Published private(set) var selectedSuggestionIndex: Int? = nil

    // Tap-thread state — never touch from main thread
    private var tapState: TapState = .idle
    private var tapBuffer: String = ""
    private var rollingBuffer: [Character] = []
    private var tapSuggestions: [ComposeSuggestion] = []
    private var tapSelectedIndex: Int? = nil

    private var composeTable: [String: String]
    private let tableLock = NSLock()
    let settings: SettingsStore

    init(composeTable: [String: String], settings: SettingsStore) {
        self.composeTable = composeTable
        self.settings = settings
    }

    // MARK: - Table reload (called from main thread)

    func reload(table: [String: String]) {
        tableLock.withLock { composeTable = table }
        transitionToIdle()
    }

    // MARK: - Entry point (called from event tap thread)

    func process(keyCode: CGKeyCode, character: Character?) -> EventTapAction {
        switch tapState {
        case .idle:      return processIdle(keyCode: keyCode, character: character)
        case .composing: return processComposing(keyCode: keyCode, character: character)
        }
    }

    // MARK: - Idle state

    private func processIdle(keyCode: CGKeyCode, character: Character?) -> EventTapAction {
        if keyCode == 51 {  // Backspace
            if !rollingBuffer.isEmpty { rollingBuffer.removeLast() }
            return .passThrough
        }

        guard let char = character, !char.isNewline, char != "\0" else {
            rollingBuffer.removeAll()
            return .passThrough
        }

        let prefix = settings.prefix
        rollingBuffer.append(char)
        if rollingBuffer.count > prefix.count {
            rollingBuffer.removeFirst(rollingBuffer.count - prefix.count)
        }

        if rollingBuffer.count == prefix.count && String(rollingBuffer) == prefix {
            rollingBuffer.removeAll()
            tapState = .composing
            tapBuffer = ""
            DispatchQueue.main.async {
                self.uiState = .composing
                self.uiBuffer = ""
                self.suggestions = []
                self.selectedSuggestionIndex = nil
            }
            // All prefix chars have already passed through to the text field — nothing to erase.
        }

        return .passThrough
    }

    // MARK: - Composing state

    private func processComposing(keyCode: CGKeyCode, character: Character?) -> EventTapAction {
        // Backspace: always pass through so the text field erases naturally.
        if keyCode == 51 {
            if tapBuffer.isEmpty {
                // Backspace on empty buffer erases the last prefix char — exit composing.
                transitionToIdle()
            } else {
                tapBuffer.removeLast()
                let newBuffer = tapBuffer
                let newSuggestions = computeSuggestions(for: newBuffer)
                tapSuggestions = newSuggestions
                tapSelectedIndex = nil
                DispatchQueue.main.async {
                    self.uiBuffer = newBuffer
                    self.suggestions = newSuggestions
                    self.selectedSuggestionIndex = nil
                }
            }
            return .passThrough
        }

        // Down arrow — move selection forward through suggestions.
        if keyCode == 125 {
            guard !tapSuggestions.isEmpty else { return .passThrough }
            let next = min((tapSelectedIndex ?? -1) + 1, tapSuggestions.count - 1)
            tapSelectedIndex = next
            let idx = next
            DispatchQueue.main.async { self.selectedSuggestionIndex = idx }
            return .suppress
        }

        // Up arrow — move selection backward; deselect when going past the top.
        if keyCode == 126 {
            guard tapSelectedIndex != nil else { return .passThrough }
            let prev: Int? = tapSelectedIndex! > 0 ? tapSelectedIndex! - 1 : nil
            tapSelectedIndex = prev
            let idx = prev
            DispatchQueue.main.async { self.selectedSuggestionIndex = idx }
            return .suppress
        }

        // Return — accept selected suggestion or cancel composing.
        if keyCode == 36 {
            if let idx = tapSelectedIndex, idx < tapSuggestions.count {
                let result = tapSuggestions[idx].result
                let eraseCount = settings.prefix.count + tapBuffer.count
                transitionToIdle()
                return .suppressAndEmit([.backspace(eraseCount), .unicode(result)])
            }
            // No suggestion selected — treat Return as cancel (don't insert a newline mid-compose).
            transitionToIdle()
            return .passThrough
        }

        guard let char = character, !char.isNewline, char != "\0" else {
            return .passThrough
        }

        tapBuffer.append(char)
        let newBuffer = tapBuffer
        let prefix = settings.prefix

        // 1. Exact match → suppress this char (it never reaches the text field),
        //    erase everything visible (prefix + earlier compose chars), emit result.
        //    Visible chars = prefix.count + (newBuffer.count - 1)  [triggering char was suppressed]
        let exactMatch = tableLock.withLock { composeTable[newBuffer] }
        if let result = exactMatch {
            let eraseCount = prefix.count + newBuffer.count - 1
            transitionToIdle()
            return .suppressAndEmit([.backspace(eraseCount), .unicode(result)])
        }

        // 2. No sequence starts with this buffer → pass through, return to idle.
        //    The chars are already in the text field verbatim — nothing to clean up.
        if !hasPrefixMatch(for: newBuffer) {
            transitionToIdle()
            return .passThrough
        }

        // 3. Still ambiguous → pass through, update suggestions popup.
        let newSuggestions = computeSuggestions(for: newBuffer)
        tapSuggestions = newSuggestions
        tapSelectedIndex = nil
        DispatchQueue.main.async {
            self.uiBuffer = newBuffer
            self.suggestions = newSuggestions
            self.selectedSuggestionIndex = nil
        }
        return .passThrough
    }

    // MARK: - External cancellation (called from tap thread on mouse-down)

    /// Aborts composing if active, so a click-away cleanly resets state.
    /// The `::` already in the text field is left as-is (verbatim).
    func cancelIfComposing() {
        guard tapState == .composing else { return }
        transitionToIdle()
    }

    // MARK: - Helpers

    private func transitionToIdle() {
        tapState = .idle
        tapBuffer = ""
        rollingBuffer.removeAll()
        tapSuggestions = []
        tapSelectedIndex = nil
        DispatchQueue.main.async {
            self.uiState = .idle
            self.uiBuffer = ""
            self.suggestions = []
            self.selectedSuggestionIndex = nil
        }
    }

    private func hasPrefixMatch(for buffer: String) -> Bool {
        tableLock.withLock { composeTable.keys.contains { $0.hasPrefix(buffer) } }
    }

    /// Safe to call from either thread. Returns one-step completions sorted by next character (≤ 20).
    private func computeSuggestions(for buffer: String) -> [ComposeSuggestion] {
        guard !buffer.isEmpty else { return [] }
        let snapshot = tableLock.withLock { composeTable }
        var result: [ComposeSuggestion] = []
        for (key, value) in snapshot {
            guard key.hasPrefix(buffer), key.count == buffer.count + 1 else { continue }
            result.append(ComposeSuggestion(next: String(key.last!), result: value))
        }
        return result.sorted { $0.next < $1.next }.prefix(20).map { $0 }
    }
}
