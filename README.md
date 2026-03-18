# SnippetCompose

A lightweight macOS menu bar app that brings X11-style compose key sequences system-wide. Type a prefix (default `::`) followed by a short sequence to insert Unicode characters in any app.

```
::C=  →  €        ::ss  →  ß        ::*A  →  Α
::+-  →  ±        ::ae  →  æ        ::12  →  ½
:::a  →  ä        ::co  →  ©        ::--- →  —
```

Over 3,000 sequences from the standard X11 compose table are included.

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Installation

Download the latest release, move `SnippetCompose.app` to `/Applications`, and launch it. macOS will prompt for Accessibility access — the app cannot intercept keystrokes without it.

## Usage

The default trigger prefix is `::`. Once composing starts, the menu bar icon fills in. Type a sequence and it is replaced automatically when an exact match is found. Press Escape or click away to cancel.

A suggestions popup appears near the cursor while composing in apps that support the macOS Accessibility API (most native apps). The popup is not shown in terminal emulators or Electron-based apps.

Settings are available from the menu bar icon: change the prefix, toggle the popup, and enable launch at login.

## Custom sequences

On first launch, open Settings and click "Create & Open" to create `~/.compose/Compose`. Add entries in X11 format:

```
<Multi_key> <a> <b> : "result"
```

Click "Reload" in Settings after editing the file.

## Building from source

Requires Xcode 15 or later.

```bash
git clone https://github.com/yourusername/SnippetCompose
open SnippetCompose.xcodeproj
```

Press `⌘R` to build and run. The app must not be sandboxed — `CGEventTapCreate` silently fails inside a sandbox.
