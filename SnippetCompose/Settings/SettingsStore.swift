import Foundation
import ServiceManagement

class SettingsStore: ObservableObject {
    @Published var prefix: String {
        didSet { UserDefaults.standard.set(prefix, forKey: "prefix") }
    }
    @Published var showPopup: Bool {
        didSet { UserDefaults.standard.set(showPopup, forKey: "showPopup") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[SettingsStore] launchAtLogin error: \(error)")
            }
        }
    }

    init() {
        self.prefix = UserDefaults.standard.string(forKey: "prefix") ?? "::"
        self.showPopup = UserDefaults.standard.object(forKey: "showPopup") as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    static let userComposeFileURL: URL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".compose/Compose")

    var userComposeFileExists: Bool {
        FileManager.default.fileExists(atPath: Self.userComposeFileURL.path)
    }
}
