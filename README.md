# VzheClip

**Clipboard history for macOS — like Windows' Win+V.** Press **⌥V** anywhere to see your
recent copies (text *and* images, with previews) and paste any of them straight into the app
you're using.

- Lives in the menu bar, starts at login, no Dock icon
- Keeps the last 20 copies (adjustable 5–100); pinned items are kept forever
- Image copies show a thumbnail preview with their dimensions
- Type to search; keyboard-first (↑/↓, Enter, ⌘1–⌘9)
- Skips passwords from password managers (concealed/transient clipboard content) and
  copies made in apps you exclude
- Everything stays on your Mac (`~/Library/Application Support/VzheClip`)

Requires macOS 14 Sonoma or later.

## Install

1. Download `VzheClip-<version>.dmg` from the [latest release](https://github.com/vzhe-blackthorn/vzhe-clip/releases/latest).
2. Open it and drag **VzheClip** onto **Applications**.
3. Launch VzheClip from Applications. A clipboard icon appears in the menu bar and a
   welcome window explains the basics.
4. Click **Grant Accessibility…** and enable VzheClip in
   **System Settings → Privacy & Security → Accessibility**. This lets VzheClip paste into
   other apps; without it, picking an entry only copies it to the clipboard.

VzheClip registers itself to open at login on first launch (toggle it in Settings).

## Usage

| Where | Key | Action |
|---|---|---|
| Anywhere | **⌥V** | Open / close the history panel (rebind in Settings) |
| Panel | type | Search (images match the name of the app they were copied from) |
| Panel | ↑ / ↓ | Move selection |
| Panel | Enter / click | Paste the selected entry |
| Panel | ⌘1 … ⌘9 | Paste the Nth entry |
| Panel | ⌘P | Pin / unpin |
| Panel | ⌫ (empty search) | Delete the selected entry |
| Panel | Esc / click outside | Close |

Right-click a card for Paste / Pin / Delete. The menu-bar icon offers Show History, Pause
Capture, Clear History (keeps pinned items), Settings and Quit.

**Settings:** history size, hotkey, launch at login, and a list of apps whose copies are
never recorded (1Password and Keychain Access by default).

## Build from source

```sh
brew install xcodegen
git clone https://github.com/vzhe-blackthorn/vzhe-clip.git && cd vzhe-clip
scripts/test.sh     # run the unit tests
scripts/build.sh    # Debug build → build/Build/Products/Debug/VzheClip.app
```

To build with your own Apple team, change `DEVELOPMENT_TEAM` in `project.yml`.

## Releasing

`scripts/release.sh` builds a Release app with Hardened Runtime, signs it with your
**Developer ID Application** certificate, packages `build/release/VzheClip-<version>.dmg`,
then notarizes and staples it. One-time setup is described at the top of the script.
Bump `CFBundleShortVersionString` / `CFBundleVersion` in `project.yml` before each release.

## Uninstall

Quit VzheClip from its menu, delete it from Applications, then optionally remove
`~/Library/Application Support/VzheClip` and run `defaults delete com.vzh.VzheClip`.

## Contributing

VzheClip is open source — issues and pull requests are welcome. Please run `scripts/test.sh`
before opening a PR; `CLAUDE.md` describes the architecture and behaviour spec.

## License

[MIT](LICENSE) © 2026 Volodymyr Zherdetskyi. Uses [GRDB.swift](https://github.com/groue/GRDB.swift)
and [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (both MIT).
