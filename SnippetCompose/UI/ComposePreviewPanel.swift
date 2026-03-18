import AppKit
import SwiftUI
import Combine

// MARK: - NSPanel subclass

final class ComposePanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            // No .hudWindow — its own chrome conflicts with our custom rounded rect.
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Re-entrancy-safe NSHostingView

/// SwiftUI's sizeThatFits implementation calls setNeedsUpdateConstraints on the
/// hosting view while we are already inside updateConstraints. AppKit detects
/// this re-entrancy and crashes. We guard against it by swallowing any
/// setNeedsUpdateConstraints call that arrives during our own updateConstraints.
private final class PanelHostingView: NSHostingView<AnyView> {
    private var isInUpdateConstraints = false

    override func updateConstraints() {
        isInUpdateConstraints = true
        defer { isInUpdateConstraints = false }
        super.updateConstraints()
    }

    override var needsUpdateConstraints: Bool {
        get { super.needsUpdateConstraints }
        set {
            guard !isInUpdateConstraints else { return }
            super.needsUpdateConstraints = newValue
        }
    }

    required init(rootView: AnyView) { super.init(rootView: rootView) }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}

// MARK: - Controller

final class PanelController {
    private let panel = ComposePanel()
    private let hostingView: PanelHostingView
    private var cancellables = Set<AnyCancellable>()
    private let stateMachine: ComposeStateMachine

    init(stateMachine: ComposeStateMachine) {
        self.stateMachine = stateMachine

        let rootView = AnyView(
            ComposePreviewView()
                .environmentObject(stateMachine)
                .environmentObject(stateMachine.settings)
        )
        let hv = PanelHostingView(rootView: rootView)
        // Transparent host view so the panel corners are truly see-through.
        hv.wantsLayer = true
        hv.layer?.backgroundColor = .clear
        hv.sizingOptions = []
        self.hostingView = hv
        panel.contentView = hv

        // Show as soon as composing starts, hide on return to idle.
        stateMachine.$uiState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .composing: self?.repositionAndShow()
                case .idle:      self?.hide()
                }
            }
            .store(in: &cancellables)

        // Reposition whenever suggestions change (panel may resize).
        stateMachine.$suggestions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard self?.stateMachine.uiState == .composing else { return }
                self?.repositionAndShow()
            }
            .store(in: &cancellables)
    }

    private func repositionAndShow() {
        guard stateMachine.settings.showPopup else { return }
        // If the caret position is unavailable (Electron/Chromium apps don't implement
        // kAXBoundsForRangeParameterizedAttribute), hide rather than show the panel at
        // an arbitrary position.
        guard let topLeft = CursorPositionProvider.topLeftBelowCaret() else {
            hide()
            return
        }
        let size = hostingView.fittingSize
        panel.setContentSize(size)
        panel.setFrameTopLeftPoint(topLeft)
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel.orderOut(nil)
    }
}
