import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var stateMachine: ComposeStateMachine

    @State private var prefixInput: String = ""

    @State private var fileExists: Bool = false
    @State private var entryCount: Int? = nil
    @State private var loadError: String? = nil

    var body: some View {
        Form {
            Section("Compose Trigger") {
                LabeledContent("Trigger prefix") {
                    HStack {
                        TextField("e.g. ::", text: $prefixInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .onSubmit { savePrefix() }
                        Button("Save") { savePrefix() }
                    }
                }
                Toggle("Show suggestions popup", isOn: $settings.showPopup)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("User Compose File") {
                LabeledContent("Path") {
                    Text("~/.compose/Compose")
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("Status") {
                    statusText
                }

                HStack {
                    if fileExists {
                        Button("Open in Editor") { openInEditor() }
                        Button("Reload") { reloadTable() }
                    } else {
                        Button("Create & Open") { createAndOpen() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .onAppear { refresh() }
    }

    @ViewBuilder
    private var statusText: some View {
        if let error = loadError {
            Text(error)
                .foregroundStyle(.red)
        } else if fileExists, let count = entryCount {
            Text("\(count) entries loaded")
                .foregroundStyle(.secondary)
        } else if fileExists {
            Text("File exists")
                .foregroundStyle(.secondary)
        } else {
            Text("Not created")
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        prefixInput = settings.prefix
        fileExists = settings.userComposeFileExists
    }

    private func savePrefix() {
        let trimmed = prefixInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { settings.prefix = trimmed }
    }

    private func createAndOpen() {
        let dest = SettingsStore.userComposeFileURL
        do {
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let src = Bundle.main.url(forResource: "Compose", withExtension: "txt")!
            try FileManager.default.copyItem(at: src, to: dest)
            fileExists = true
            loadError = nil
            let table = ComposeTableParser.load(from: dest, prefix: settings.prefix)
            entryCount = table.count
            stateMachine.reload(table: table)
            NSWorkspace.shared.open(dest)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func openInEditor() {
        NSWorkspace.shared.open(SettingsStore.userComposeFileURL)
    }

    private func reloadTable() {
        let url = SettingsStore.userComposeFileURL
        let table = ComposeTableParser.load(from: url, prefix: settings.prefix)
        if table.isEmpty {
            loadError = "No entries parsed — check file format"
        } else {
            loadError = nil
            entryCount = table.count
            stateMachine.reload(table: table)
        }
    }
}
