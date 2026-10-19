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
- Responsive layout for smaller windows and light/dark-friendly system surfaces.

The next native implementation step would be to move the note model and autosave coordinator into Swift/AppKit while preserving this interaction model.
