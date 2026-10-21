import AppKit
import Foundation

/// Monitors global keyboard shortcuts (e.g. Cmd + Option + Shift + M) for emergency pause/resume.
public final class GlobalShortcutMonitor {
    public static let shared = GlobalShortcutMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isStarted = false

    public var onToggleRequested: (() -> Void)?

    public init() {}

    deinit {
        stop()
    }

    /// Starts listening for the safety shortcut (Cmd + Option + Shift + M).
    public func start() {
        guard !isStarted else { return }
        isStarted = true

        // Global monitor for when other applications are active
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor for when GlideFix's own popover is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self = self, self.isTargetShortcut(event) {
                self.triggerToggle()
                return nil // Swallow event
            }
            return event
        }
    }

    /// Stops shortcut monitors.
    public func stop() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
        isStarted = false
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if isTargetShortcut(event) {
            DispatchQueue.main.async { [weak self] in
                self?.triggerToggle()
            }
        }
    }

    private func isTargetShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredFlags: NSEvent.ModifierFlags = [.command, .option, .shift]

        // Check if Cmd + Option + Shift are pressed
        guard flags.contains(requiredFlags) else { return false }

        // ANSI 'M' key code is 46, or charactersIgnoringModifiers == "m" / "M"
        if event.keyCode == 46 || event.charactersIgnoringModifiers?.lowercased() == "m" {
            return true
        }
        return false
    }

    private func triggerToggle() {
        if let callback = onToggleRequested {
            callback()
        } else {
            AppSettings.shared.isEnabled.toggle()
        }
    }
}
