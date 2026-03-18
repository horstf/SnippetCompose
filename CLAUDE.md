# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Requires **Xcode** (not just command-line tools). Open the project and run:

```bash
open SnippetCompose.xcodeproj   # then ⌘R in Xcode
```

Run tests: `⌘U` in Xcode, or via command line (once a developer team is set):

```bash
xcodebuild test -project SnippetCompose.xcodeproj -scheme SnippetComposeTests -destination 'platform=macOS'
```

Run a single test class:

```bash
xcodebuild test -project SnippetCompose.xcodeproj -scheme SnippetComposeTests \
  -destination 'platform=macOS' -only-testing SnippetComposeTests/ComposeTableParserTests
```

**Critical build requirement**: the app must NOT be sandboxed (`com.apple.security.app-sandbox` absent from `SnippetCompose.entitlements`). Sandboxing silently breaks `CGEventTapCreate`.

On first launch, macOS will prompt for Accessibility access (System Settings → Privacy & Security → Accessibility). Without it, the event tap fails to create and nothing intercepts keystrokes.

## Architecture

The app is a non-activating menu bar agent (`LSUIElement = true`). All major objects are owned by `AppDelegate` and share a single `SettingsStore` instance (created together in `AppDelegate.init()` to avoid a split-brain bug).

### Threading model — the most important thing to understand

There are two threads that matter:

1. **Event tap thread** (`com.hypersnippet.eventtap`) — a dedicated `Thread` running `CFRunLoopRun()`. `EventTapManager.handle()` and all `ComposeStateMachine.process/cancel` calls happen here. This thread must never call `CGEventPost` directly (re-entrant deadlock).

2. **Main thread** — SwiftUI, Combine publishers, `PanelController`, `CursorPositionProvider` AX calls.

`ComposeStateMachine` has **two parallel state representations**:
- `tapState` / `tapBuffer` / `rollingBuffer` — private, accessed only from the tap thread
- `@Published uiState` / `uiBuffer` / `suggestions` — updated via `DispatchQueue.main.async`, consumed by SwiftUI

Never read or write the tap-thread variables from the main thread.

### Keystroke flow

```
Physical key
  → CGEventTap callback (tap thread)
    → EventTapManager.handle()
      → ComposeStateMachine.process() → EventTapAction
        • .passThrough          → return event unmodified
        • .suppress             → return nil (+ track keyCode for keyUp suppression)
        • .suppressAndEmit([…]) → return nil + DispatchQueue.global.async {
                                    SyntheticEventEmitter.post…()
                                  }
```

Synthetic events are stamped with `SyntheticEventEmitter.marker` (`0x48595045`, "HYPE") via `CGEventSource.userData`. The tap callback checks this field first and passes them through immediately, preventing infinite re-processing.

### Compose state machine

**Idle**: all keys pass through. A `rollingBuffer` of the last `prefix.count` chars is maintained. When it matches `settings.prefix` (default `"::"`), the state transitions to `.composing` — the prefix chars are already in the text field (nothing is erased at transition time).

**Composing**: keys continue to pass through (user sees them in the text field). On each char:
1. **Exact match** in `composeTable` → suppress the final char, emit `[.backspace(prefix.count + buffer.count - 1), .unicode(result)]` to replace everything visible
2. **No prefix match** → pass through, return to idle (chars remain verbatim)
3. **Ambiguous** → pass through, update suggestions popup

Any mouse-down event (monitored via the same tap) calls `cancelIfComposing()`, resetting state without touching the text field.

### Compose table

`Compose.txt` (X11 format, bundled as a resource, ~3,200 entries) is parsed at startup by `ComposeTableParser`. Keys are the character sequences to type (e.g. `"C="`, `"oo"`, `"---"`); values are the resulting Unicode strings.

**Parser gotcha**: the X11 file uses tabs before the `:` separator, not spaces. The parser anchors on `": \""` (colon-space-doublequote) to find the split point. Do not change this to `" : "`.

`resolveKeysym()` maps X11 keysym names to characters. `dead_*` keys are skipped. Unknown keysyms return `nil` and cause the whole entry to be dropped. Add new keysym mappings here if sequences don't work.

### Popup panel

`PanelController` owns a `ComposePanel` (borderless, non-activating `NSPanel`, level `.floating`) hosting a `NSHostingView<ComposePreviewView>`. The panel has `backgroundColor = .clear` and `isOpaque = false`; the `NSHostingView` layer background is also cleared so the rounded SwiftUI material doesn't leak rectangular corners.

Positioning uses `setFrameTopLeftPoint` (not `setFrameOrigin`) so the panel is anchored at its top edge and grows downward as suggestions appear. The caret position comes from `AXUIElement` → `kAXBoundsForRangeParameterizedAttribute`; mouse location is the fallback.

`ComposePreviewView` uses `.background(.ultraThinMaterial, in: RoundedRectangle(...))` which clips the material fill to the shape — this is what prevents the sharp-corner artifact.
