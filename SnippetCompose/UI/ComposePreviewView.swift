import SwiftUI

struct ComposePreviewView: View {
    @EnvironmentObject var stateMachine: ComposeStateMachine
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Current input line
            HStack(spacing: 4) {
                Text(settings.prefix)
                    .foregroundStyle(.secondary)
                    .monospaced()
                Text(stateMachine.uiBuffer.isEmpty ? "▌" : stateMachine.uiBuffer + "▌")
                    .foregroundStyle(.primary)
                    .monospaced()
            }
            .font(.system(size: 14, weight: .medium))

            if !stateMachine.suggestions.isEmpty {
                Divider().padding(.vertical, 1)
                SuggestionsList(
                    suggestions: stateMachine.suggestions,
                    selectedIndex: stateMachine.selectedSuggestionIndex
                )
            } else if stateMachine.uiBuffer.isEmpty {
                Text("type a compose sequence…")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        // Material fill clipped to the rounded shape — this is what prevents
        // the rectangular host-view corners from showing through.
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .fixedSize()
    }
}

// MARK: - Suggestions list

private struct SuggestionsList: View {
    let suggestions: [ComposeSuggestion]
    let selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, s in
                SuggestionRow(next: s.next, result: s.result, isSelected: index == selectedIndex)
            }
        }
    }
}

private struct SuggestionRow: View {
    let next: String
    let result: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(next)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .monospaced()
                .font(.system(size: 12))
            Text(result)
                .foregroundStyle(.primary)
                .font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}
