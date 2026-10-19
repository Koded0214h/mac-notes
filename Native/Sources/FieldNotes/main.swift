import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = NoteStore()
    private let shortcutManager = ShortcutManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Field Notes")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        let root = NotesView(store: store, dismiss: { [weak self] in self?.hidePopover() })
        let hosting = NSHostingController(rootView: root)
        popover = NSPopover()
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 720, height: 560)
        popover.behavior = .transient
        popover.animates = true
        shortcutManager.start { [weak self] in self?.togglePopover(nil) }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown { hidePopover() } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func hidePopover() { popover.performClose(nil) }
}
