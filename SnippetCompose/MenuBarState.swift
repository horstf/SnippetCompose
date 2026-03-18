import Foundation

/// Tiny observable shared between AppDelegate and SnippetComposeApp so the
/// App-level Scene body can react to composing state changes.
final class MenuBarState: ObservableObject {
    static let shared = MenuBarState()
    @Published var isComposing: Bool = false
    private init() {}
}
