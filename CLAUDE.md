# VzheClip — macOS clipboard history (Win+V for Mac)

A menu-bar utility that records the most recent clipboard entries (text and images)
and shows them in a popup near the cursor when the user presses **⌥V**. Picking an
entry pastes it into the app the user was working in.

This file is the product spec and the working agreement for Claude Code. Keep it
current: when behaviour changes, update the relevant section in the same commit.

---

## 1. Goals & success criteria

- Launches automatically at login, lives only in the menu bar (no Dock icon).
- ⌥V (rebindable) opens the history panel in **< 100 ms**, from any app.
- History holds **text and images**; images show an inline thumbnail preview.
- Selecting an entry **auto-pastes** it into the previously focused app.
- History survives reboot (SQLite on disk) and is capped (default **20** entries).
- Idle footprint: < 60 MB RAM, ~0% CPU.

## 2. Tech stack (decided)

| Concern            | Choice                                                            |
|--------------------|-------------------------------------------------------------------|
| Language           | Swift 6 (strict concurrency), macOS 14+ deployment target         |
| App shell          | AppKit (`NSApplication`, `NSStatusItem`, `NSPanel`)               |
| Views              | SwiftUI hosted in `NSHostingView`                                 |
| Persistence        | SQLite via **GRDB.swift** (SPM)                                   |
| Global hotkey      | **KeyboardShortcuts** (sindresorhus, SPM), default ⌥V            |
| Launch at login    | `SMAppService.mainApp`                                            |
| Auto-paste         | `CGEvent` ⌘V post — requires Accessibility permission             |
| Project generation | **XcodeGen** (`project.yml` is the source of truth; `.xcodeproj` is gitignored) |
| Tests              | XCTest                                                            |

Not sandboxed (posting key events into other apps is incompatible with App Sandbox).
`LSUIElement = YES` in Info.plist. Bundle id: `com.vzh.VzheClip`.

Only the two SPM dependencies above are allowed without asking first.

## 3. Architecture

```
VzheClip/
├─ App/
│  ├─ AppDelegate.swift        wiring, NSStatusItem + menu, lifecycle
│  └─ main.swift / VzheClipApp.swift
├─ Capture/
│  ├─ ClipboardMonitor.swift   polls NSPasteboard.general.changeCount (0.5 s) → CapturedItem
│  └─ ItemExtractor.swift      NSPasteboard → CapturedItem? (pure; testable w/ named pasteboard)
├─ Storage/
│  ├─ HistoryStore.swift       GRDB: add/dedupe/prune/pin/delete/search/clear; single source of truth
│  ├─ ImageStore.swift         write PNG + thumbnail, delete files, orphan cleanup
│  └─ Models.swift             ClipItem, CapturedItem, ItemKind
├─ Hotkey/
│  └─ HotkeyManager.swift      KeyboardShortcuts name `.toggleHistory`, default ⌥V
├─ Panel/
│  ├─ PanelController.swift    borderless, non-activating NSPanel; show/hide; positioning
│  ├─ PanelPlacement.swift     pure func: cursor point + screen frame → panel origin (clamped)
│  ├─ HistoryView.swift        search field + card list + keyboard handling
│  └─ ClipCardView.swift       text card / image-thumbnail card
├─ Paste/
│  ├─ Paster.swift             write item to pasteboard, hide panel, post ⌘V
│  └─ PermissionsHelper.swift  AXIsProcessTrusted / prompt / open System Settings
├─ Settings/
│  ├─ SettingsView.swift       limit, hotkey recorder, launch at login, deny-list, clear all
│  ├─ Preferences.swift        UserDefaults-backed settings
│  └─ LoginItem.swift          SMAppService wrapper
VzheClipTests/
project.yml
```

Rules of thumb: each file has one responsibility; `ItemExtractor`, `HistoryStore`,
`PanelPlacement` must stay free of UI so they're unit-testable. `HistoryStore` is the
only thing that touches the database.

### Data flow

- **Capture:** `ClipboardMonitor` detects a `changeCount` change → `ItemExtractor`
  classifies → `HistoryStore.add` (dedupe + prune) → observers (the panel's view model)
  refresh.
- **Recall:** hotkey → `PanelController.show()` near the cursor → user picks →
  `Paster.paste(item)`.
- **Self-copy suppression:** after `Paster` writes to the pasteboard it records the
  resulting `changeCount`; `ClipboardMonitor` ignores that one change (the item is just
  bumped via `HistoryStore.markUsed`).

## 4. Data model

Location: `~/Library/Application Support/VzheClip/`
- `history.sqlite`
- `images/<uuid>.png` (original) and `images/<uuid>_thumb.png` (max 480 px on the longest side)

```sql
CREATE TABLE items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  kind          TEXT    NOT NULL CHECK (kind IN ('text','image')),
  text          TEXT,                 -- full text for kind=text
  image_path    TEXT,                 -- relative to images/
  thumb_path    TEXT,
  image_w       INTEGER,
  image_h       INTEGER,
  content_hash  TEXT    NOT NULL UNIQUE,  -- SHA-256 of UTF-8 text or PNG bytes
  source_app    TEXT,                 -- bundle id of frontmost app at capture
  is_pinned     INTEGER NOT NULL DEFAULT 0,
  created_at    REAL    NOT NULL,
  last_used_at  REAL    NOT NULL
);
CREATE INDEX items_order ON items (is_pinned DESC, last_used_at DESC);
```

Use GRDB migrations (`DatabaseMigrator`) from day one; migration ids `v1`, `v2`, ...

## 5. Behaviour spec

### Capture
- Poll interval 0.5 s on the main run loop; do nothing if `changeCount` unchanged.
- **Ignore** pasteboard contents carrying any of:
  `org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`,
  `org.nspasteboard.AutoGeneratedType`.
- **Ignore** copies made while the frontmost app is on the deny-list
  (default: `com.1password.1password`, `com.agilebits.onepassword7`,
  `com.apple.keychainaccess`).
- **Classification priority:** image (`.png`, `.tiff`) > plain text (`.string`).
  Rich text (RTF/HTML) is stored as its plain-text representation. File URLs
  (Finder copies) are ignored in v1.
- Whitespace-only text is ignored.
- Text > 1 MB is truncated to 1 MB (on a character boundary). Images > 50 megapixels
  are ignored (if the pasteboard also has text, the text is captured instead).
- Images are normalised to PNG before hashing and storing.

### History rules
- **Dedupe:** if `content_hash` exists, update `last_used_at = now` (moves to top);
  do not insert a new row.
- **Limit:** default **20**, configurable **5–100**. After each insert, delete
  *unpinned* items beyond the limit (oldest `last_used_at` first) and their image files.
  **Pinned items do not count toward the limit.**
- **Order:** pinned first, then `last_used_at` descending.
- **Search:** case-insensitive substring over `text`; image items match on the source
  app's display name. Empty query shows everything.

### Panel (UI)
- Win+V-style: a single narrow column (~360 pt wide, max ~520 pt tall, scrolls) of
  cards with a search field on top. Rounded corners, `.regularMaterial` background,
  respects light/dark mode.
- **Placement:** top-left at cursor + (8, −8), clamped fully inside the visible frame
  of the screen under the cursor (`PanelPlacement`, pure and tested).
- **Non-activating** `NSPanel` (`.nonactivatingPanel`, `.floating` level,
  `canJoinAllSpaces`, `fullScreenAuxiliary`) so the previous app stays frontmost.
  The panel becomes key to receive keystrokes but must not activate VzheClip.
- **Cards:**
  - Text: up to 3 lines / ~300 chars, system font, tail-truncated.
  - Image: thumbnail scaled to card width (max ~140 pt tall), dimensions caption
    (e.g. `1920×1080`).
  - Footer: relative time ("2m ago") and source app icon.
  - Pinned: 📌 badge. Selected: accent-colour border/background.
- **Keyboard:**
  | Key                 | Action                                     |
  |---------------------|--------------------------------------------|
  | ↑ / ↓               | move selection                             |
  | Enter / click       | paste selected                             |
  | ⌘1 … ⌘9             | paste Nth visible item                     |
  | ⌘P                  | toggle pin                                 |
  | ⌫ (search empty)    | delete selected                            |
  | any printable key   | goes to search field                       |
  | Esc / click outside / ⌥V again | close                           |
- Each card also has a context menu: Paste, Pin/Unpin, Delete.
- Opening the panel always resets search and selects the first item.

### Paste
1. Write item to `NSPasteboard.general` (text as `.string`; image as PNG + TIFF).
2. Record `changeCount` for self-copy suppression; `markUsed(item)`.
3. Hide panel.
4. If `AXIsProcessTrusted()`: after ~50 ms post ⌘V (`CGEvent` keyDown/keyUp for
   `kVK_ANSI_V` with `.maskCommand`, `.cghidEventTap`).
   Else: leave the item on the clipboard (copy-only). While Accessibility is not
   granted, the panel shows a banner "Enable Accessibility to auto-paste" whose button
   opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.

### Menu-bar item
Icon (SF Symbol `doc.on.clipboard`). Menu: Show History (⌥V), Pause Capture,
Clear History…, Settings…, Quit. When Accessibility is not granted, the menu starts
with "⚠︎ Enable Accessibility for Auto-Paste…". "Clear History" (menu and Settings)
removes all **unpinned** items after confirmation; pinned items are kept (like Win+V).

### Settings
History limit (stepper 5–100), hotkey recorder, Launch at login (toggle,
`SMAppService`; default ON on first run), deny-list (bundle ids, add/remove),
Clear History (confirm; keeps pins). Settings window is a normal activating window.

### First run
Register login item, show a small onboarding window explaining ⌥V and requesting
Accessibility (`AXIsProcessTrustedWithOptions` with prompt).

## 6. Error handling

- **DB fails to open / is corrupt:** rename to `history.sqlite.corrupt-<ISO date>`,
  create fresh DB, log via `os.Logger` (subsystem `com.vzh.VzheClip`). Never crash.
- **Image file missing** when loading an item: delete the row silently.
- **Orphaned image files** (no row): removed on launch.
- **Hotkey conflicts:** the KeyboardShortcuts recorder in Settings warns when a chosen
  shortcut is taken by the system or the app menu; the user rebinds there.
- **Image decode/encode fails:** skip capture, log.
- Never log clipboard *contents*; log only kinds, sizes, and ids.

## 7. Testing

- **Unit (XCTest), required before merging each component:**
  - `HistoryStore` with in-memory `DatabaseQueue`: insert, dedupe bump, prune respects
    pins and limit, ordering, search, delete removes image files, clear all.
  - `ItemExtractor` using `NSPasteboard(name: .init("test-\(UUID())"))`: text, image,
    concealed/transient ignored, image beats text, whitespace ignored, truncation.
  - `PanelPlacement`: cursor near each screen edge/corner, multi-screen frames.
- **Manual checklist** (run before calling a milestone done):
  ⌥V from Safari, VS Code, Terminal, a full-screen app; auto-paste text and image;
  pin survives exceeding the limit; reboot → history intact and app auto-started;
  Accessibility revoked → copy-only path + banner; copy from 1Password not recorded.

## 8. Out of scope (v1)

Files/Finder copies, rich-text round-tripping, iCloud sync, snippets/templates,
OCR on images, multiple panels per display, App Store distribution.

## 9. Development workflow

- Setup: `brew install xcodegen`.
- Build: `scripts/build.sh` (runs `xcodegen generate` + Debug build).
- Test: `scripts/test.sh` (all) or `scripts/test.sh -only-testing:VzheClipTests/<Class>`.
- Both scripts regenerate the project, so new files are always picked up.
- Accessibility permission is tied to the code signature. `project.yml` signs with the
  Apple Development identity of team `H5U9AQK47X` so the grant survives rebuilds.
- TDD for all non-UI units. Keep files small and single-purpose.
- Commits: small, imperative subject line.
