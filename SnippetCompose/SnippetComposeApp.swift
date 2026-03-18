import SwiftUI

@main
struct SnippetComposeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var menuBarState = MenuBarState.shared

    var body: some Scene {
        MenuBarExtra("SnippetCompose", image: menuBarState.isComposing ? "MenuBarIconActive" : "MenuBarIcon") {
            MenuBarView()
                .environmentObject(appDelegate.settingsStore)
                .environmentObject(appDelegate.stateMachine)
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appDelegate.settingsStore)
                .environmentObject(appDelegate.stateMachine)
        }
        .windowResizability(.contentSize)
    }
}
