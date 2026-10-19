import AppKit

final class ShortcutManager {
    private var monitors: [Any] = []

    func start(handler: @escaping () -> Void) {
        let matches: (NSEvent) -> Bool = { event in
            event.keyCode == 49 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains([.command, .shift])
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            if matches(event) { handler(); return nil }
            return event
        }) { monitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            if matches(event) { handler() }
        }) { monitors.append(global) }
    }

    deinit { monitors.forEach(NSEvent.removeMonitor) }
}
