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
        if !self.isTrusted {
            startPolling()
        }
    }

    /// Checks current Accessibility authorization status directly from the tccd daemon without stale local caching.
    public func checkIsTrusted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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

    /// Starts polling permission state every 0.8 seconds in .common runloop mode.
    public func startPolling() {
        guard pollTimer == nil else { return }
        isPollingActive = true

        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.refreshTrustStatus() {
                self.stopPolling()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }

    /// Stops polling timer.
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPollingActive = false
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Accessibility.
    public func openSystemSettingsAccessibility() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(URL: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Restarts the application cleanly so macOS TCC process tokens take immediate effect.
    public static func relaunchApplication() {
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private extension URL {
    init?(URL string: String) {
        self.init(string: string)
    }
}
