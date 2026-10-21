import AppKit
import ApplicationServices
import Foundation

/// Manages macOS Accessibility permissions detection, system prompt triggers, and automatic polling.
public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()

    @Published public private(set) var isTrusted: Bool = false
    @Published public var isPollingActive: Bool = false

    private var pollTimer: Timer?
    public var onPermissionGranted: (() -> Void)?

    public init() {
        self.isTrusted = checkIsTrusted()
    }

    /// Checks current Accessibility authorization status without showing a prompt.
    public func checkIsTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Updates internal published trust state and notifies callback if newly granted.
    @discardableResult
    public func refreshTrustStatus() -> Bool {
        let trusted = checkIsTrusted()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let wasTrusted = self.isTrusted
            self.isTrusted = trusted
            if !wasTrusted && trusted {
                self.stopPolling()
                self.onPermissionGranted?()
            }
        }
        return trusted
    }

    /// Requests accessibility permission from macOS by triggering the system prompt dialog.
    public func requestPermissionWithPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    /// Starts polling permission state every 1.5 seconds while the user is granting permission.
    public func startPolling() {
        guard pollTimer == nil else { return }
        isPollingActive = true

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.refreshTrustStatus() {
                self.stopPolling()
            }
        }
    }

    /// Stops the 1.5-second polling timer.
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPollingActive = false
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Accessibility.
    public func openSystemSettingsAccessibility() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
