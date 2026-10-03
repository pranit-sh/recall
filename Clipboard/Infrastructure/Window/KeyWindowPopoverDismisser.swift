import AppKit

@MainActor
final class KeyWindowPopoverDismisser: PopoverDismissing {
    func dismissPopover() {
        guard let statusItem = menuBarStatusItem else {
            NSApp.keyWindow?.close()
            return
        }

        if cancelExpandedInterfaceSession(for: statusItem) {
            return
        }

        guard let button = statusItem.button, button.action != nil else {
            NSApp.keyWindow?.close()
            return
        }

        button.performClick(button)
    }

    private var menuBarStatusItem: NSStatusItem? {
        NSApp.windows
            .filter { $0.className.contains("NSStatusBarWindow") }
            .compactMap { $0.value(forKey: "statusItem") as? NSStatusItem }
            .first { !$0.className.contains("Replicant") }
    }

    private func cancelExpandedInterfaceSession(for statusItem: NSStatusItem) -> Bool {
        let sessionSelector = NSSelectorFromString("expandedInterfaceSession")
        let cancelSelector = NSSelectorFromString("cancel")

        guard statusItem.responds(to: sessionSelector),
              let session = statusItem.perform(sessionSelector)?.takeUnretainedValue() as? NSObject,
              session.responds(to: cancelSelector) else {
            return false
        }

        session.perform(cancelSelector)
        return true
    }
}
