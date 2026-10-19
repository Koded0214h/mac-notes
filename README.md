# Field Notes

A focused, offline-first notes popover prototype for macOS.

## Run it

Open `index.html` directly in a browser. The prototype has no build step and stores notes in `localStorage` under `field-notes-v1`.

## Included in this slice

- Compact macOS menu bar presentation with a menu bar icon affordance.
- Multiple notes with create, switch, rename, pin, delete, and search.
- Markdown-compatible editor with quick formatting controls.
- Debounced autosave with visible save state and restart persistence.
- Keyboard shortcuts: `⌘N` for a note and `⌘F` for search.
- `⌘S` saves immediately, `⌘↑` and `⌘↓` move through notes.
- Preview rendered Markdown and export the current note as a `.md` file.
- Import existing `.md` or `.markdown` files into the notebook.
- Responsive layout for smaller windows and light/dark-friendly system surfaces.

The browser prototype remains useful for fast interaction testing; the native implementation lives in `Native/`.

## Native macOS slice

`Native/` contains the AppKit menu bar shell and SwiftUI popover implementation for macOS 13+. Open `Native/Package.swift` in Xcode and run the `FieldNotes` executable. The native slice writes UTF-8 Markdown files to `~/Library/Application Support/Field Notes/Notes/` and keeps metadata separate.

If you do not have Xcode, run `cd Native && ./build-app.sh --open`. The script uses the Swift toolchain and command line frameworks already included with macOS developer tools, builds the app bundle, signs it locally, and opens it in the menu bar.
