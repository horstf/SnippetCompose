# SnippetCompose

A lightweight macOS menu bar app that brings X11-style compose key sequences system-wide. Type a prefix (default `::`) followed by a short sequence to insert Unicode characters in any app.

```
::C=  →  €        ::ss  →  ß        ::*a  →  α
::+-  →  ±        ::ae  →  æ        ::12  →  ½
:::a  →  ä        ::co  →  ©        ::--- →  —
```

Over 900 sequences are included by default, and they can be customized (see below).

## Requirements

- macOS 13 or later
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Installation

Download the latest release from the releases page. macOS will prompt for Accessibility access — the app cannot intercept keystrokes without it.

## Usage

The default trigger prefix is `::`, this is customizable. After typing the prefix, the next characters are considered inputs for a compose sequence and the whole input is replaced when an exact match is found. Press Escape or click away to cancel.

A suggestions popup appears near the cursor while composing in apps that support the macOS Accessibility API (most native apps). The popup is not shown in terminal emulators or Electron-based apps. It can be turned off in the settings.

## Custom sequences

From the settings a Compose file can be created in `~/.compose/Compse` which allows editing of the included Compose sequences as well as adding new ones.

Add entries in X11 format:
```
<Multi_key> <key_1> <key_2> : "result_character"
```

Click "Reload" in Settings after editing the file.

## Building from source

Requires Xcode 15 or later.

```bash
git clone https://github.com/yourusername/SnippetCompose
open SnippetCompose.xcodeproj
```
