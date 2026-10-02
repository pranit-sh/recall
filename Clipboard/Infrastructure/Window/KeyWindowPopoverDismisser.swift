import AppKit

@MainActor
final class KeyWindowPopoverDismisser: PopoverDismissing {
    func dismissPopover() {
        NSApp.keyWindow?.close()
    }
}
