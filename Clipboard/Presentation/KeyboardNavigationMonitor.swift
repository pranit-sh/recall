import AppKit
import SwiftUI

struct KeyboardNavigationMonitor: NSViewRepresentable {
    let onMove: (Int) -> Void
    let onConfirm: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMove: onMove, onConfirm: onConfirm)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onMove = onMove
        context.coordinator.onConfirm = onConfirm
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var onMove: (Int) -> Void
        var onConfirm: () -> Void

        private var eventMonitor: Any?

        init(onMove: @escaping (Int) -> Void, onConfirm: @escaping () -> Void) {
            self.onMove = onMove
            self.onConfirm = onConfirm
        }

        func start() {
            guard eventMonitor == nil else { return }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                switch event.keyCode {
                case 125:
                    self?.onMove(1)
                    return nil
                case 126:
                    self?.onMove(-1)
                    return nil
                case 36, 76:
                    self?.onConfirm()
                    return nil
                default:
                    return event
                }
            }
        }

        func stop() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
