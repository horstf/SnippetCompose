import XCTest
@testable import SnippetCompose

// MARK: - Compose table parser tests

final class ComposeTableParserTests: XCTestCase {

    var table: [String: String] = [:]

    override func setUpWithError() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "Compose", withExtension: "txt")
            ?? URL(fileURLWithPath: "/opt/homebrew/Cellar/libx11/1.8.12/share/X11/locale/en_US.UTF-8/Compose")
        table = ComposeTableParser.load(from: url)
    }

    func testEntryCount() {
        XCTAssertGreaterThanOrEqual(table.count, 676, "Expected at least 676 entries, got \(table.count)")
    }

    func testEllipsis()            { XCTAssertEqual(table[".."], "…") }
    func testDoubleQuoteLow()      { XCTAssertEqual(table[",,"], "„") }
    func testGreekAlpha()          { XCTAssertEqual(table["*a"], "α") }
    func testGreekAlphaUpper()     { XCTAssertEqual(table["*A"], "Α") }
    func testRightDoubleQuote()    { XCTAssertEqual(table["''"], "\u{201D}") }
}

// MARK: - State machine tests

final class ComposeStateMachineTests: XCTestCase {

    var sm: ComposeStateMachine!

    override func setUp() {
        // Small table with a variety of prefix overlaps
        let table: [String: String] = [
            "C=":  "€",   // two-char sequence
            "oo":  "°",   // two-char, same char repeated
            "!!":  "¡",
            "---": "—",   // three-char sequence
        ]
        sm = ComposeStateMachine(composeTable: table, settings: SettingsStore())
    }

    @discardableResult
    private func key(_ char: Character) -> EventTapAction {
        sm.process(keyCode: 0, character: char)
    }

    private func backspace() -> EventTapAction {
        sm.process(keyCode: 51, character: nil)
    }

    private func name(_ a: EventTapAction) -> String {
        switch a {
        case .passThrough:     return "passThrough"
        case .suppress:        return "suppress"
        case .suppressAndEmit: return "suppressAndEmit"
        }
    }

    // MARK: Prefix detection — all chars pass through

    func testPrefixCharsAllPassThrough() {
        XCTAssertEqual(name(key(":")), "passThrough")   // first  :
        XCTAssertEqual(name(key(":")), "passThrough")   // second : — triggers composing but still passes through
    }

    // MARK: Composing — intermediate chars pass through

    func testComposingCharsPassThrough() {
        enterComposing()
        // "C" is ambiguous (prefix of "C=") → passes through
        XCTAssertEqual(name(key("C")), "passThrough")
    }

    // MARK: Auto-commit on exact match

    func testAutoCommitEuroSign() {
        // Text field: ::C=  →  €
        // eraseCount = prefix(2) + buffer("C=").count - 1 = 3
        enterComposing()
        key("C")
        let a = key("=")
        assertEmitsBackspacesThen(3, unicode: "€", action: a, label: "C= → €")
    }

    func testAutoCommitDegreeSign() {
        enterComposing()
        key("o")
        let a = key("o")
        assertEmitsBackspacesThen(3, unicode: "°", action: a, label: "oo → °")
    }

    func testAutoCommitThreeCharSequence() {
        // eraseCount = 2 + 3 - 1 = 4
        enterComposing()
        key("-"); key("-")
        let a = key("-")
        assertEmitsBackspacesThen(4, unicode: "—", action: a, label: "--- → —")
    }

    // MARK: No-match — pass through, leave chars in text field

    func testNoMatchPassesThrough() {
        enterComposing()
        // "z" has no prefix in the test table → pass through, back to idle
        XCTAssertEqual(name(key("z")), "passThrough")
    }

    func testNoMatchAfterPartialBufferPassesThrough() {
        enterComposing()
        key("C")                            // "C" is a valid prefix
        let a = key("x")                    // "Cx" → no match
        XCTAssertEqual(name(a), "passThrough")
    }

    // MARK: Backspace

    func testBackspaceInIdlePassesThrough() {
        XCTAssertEqual(name(backspace()), "passThrough")
    }

    func testBackspaceInComposingPassesThrough() {
        enterComposing()
        key("C")
        XCTAssertEqual(name(backspace()), "passThrough")
    }

    func testBackspaceOnEmptyComposingBufferExitsComposing() {
        enterComposing()
        // Empty buffer backspace → exit composing (erases a prefix char from text field)
        XCTAssertEqual(name(backspace()), "passThrough")
        // After exiting, the next `:` should pass through in idle mode (not re-trigger composing)
        XCTAssertEqual(name(key("C")), "passThrough")
    }

    func testBackspaceUnwindAndRecompose() {
        // Type ::C, backspace, then type ::oo → °
        enterComposing()
        key("C")
        backspace()        // buffer back to ""
        key("o")           // buffer = "o", still composing
        let a = key("o")   // "oo" → exact match
        assertEmitsBackspacesThen(3, unicode: "°", action: a, label: "backspace then oo → °")
    }

    // MARK: Helpers

    private func enterComposing() {
        key(":")   // first  ":"
        key(":")   // second ":" — transitions to composing (passes through)
    }

    private func assertEmitsBackspacesThen(
        _ expectedErase: Int,
        unicode expectedSymbol: String,
        action: EventTapAction,
        label: String
    ) {
        guard case .suppressAndEmit(let items) = action else {
            XCTFail("\(label): expected suppressAndEmit, got \(action)"); return
        }
        XCTAssertEqual(items.count, 2, "\(label): expected [backspace, unicode]")
        guard items.count == 2 else { return }

        if case .backspace(let n) = items[0] {
            XCTAssertEqual(n, expectedErase, "\(label): wrong erase count")
        } else {
            XCTFail("\(label): first item should be .backspace")
        }

        if case .unicode(let s) = items[1] {
            XCTAssertEqual(s, expectedSymbol, "\(label): wrong unicode result")
        } else {
            XCTFail("\(label): second item should be .unicode")
        }
    }
}
