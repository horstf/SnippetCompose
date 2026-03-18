import Cocoa
import ApplicationServices
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // All three are initialised together in init() so they share the same SettingsStore.
    let settingsStore: SettingsStore
    let stateMachine: ComposeStateMachine
    let eventTapManager: EventTapManager

    private var panelController: PanelController?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        let settings = SettingsStore()
        let tableURL: URL = settings.userComposeFileExists
            ? SettingsStore.userComposeFileURL
            : Bundle.main.url(forResource: "Compose", withExtension: "txt")!
        let table = ComposeTableParser.load(from: tableURL, prefix: settings.prefix)
        let sm = ComposeStateMachine(composeTable: table, settings: settings)
        self.settingsStore = settings
        self.stateMachine = sm
        self.eventTapManager = EventTapManager(stateMachine: sm)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = PanelController(stateMachine: stateMachine)
        stateMachine.$uiState
            .receive(on: DispatchQueue.main)
            .map { $0 == .composing }
            .sink { MenuBarState.shared.isComposing = $0 }
            .store(in: &cancellables)
        checkAccessibilityPermission()
    }

    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startEventTap()
        } else {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.startEventTap()
                }
            }
        }
    }

    private func startEventTap() {
        eventTapManager.start()
    }
}
