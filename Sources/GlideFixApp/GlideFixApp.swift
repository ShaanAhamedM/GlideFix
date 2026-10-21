import AppKit
import SwiftUI
import GlideFixCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Runtime Anti-Dylib Injection Enforcement
        SecurityAuditor.enforceDyldEnvironmentSafety()

        // 2. Kernel Anti-Tamper & Debugger Rejection
        SecurityAuditor.denyDebuggerAttachment()

        let accessibility = AccessibilityManager.shared
        let eventTap = EventTapManager.shared

        // Check accessibility permissions
        if accessibility.checkIsTrusted() {
            _ = eventTap.start()
        } else {
            // Setup callback for when user grants permission in System Settings
            accessibility.onPermissionGranted = { [weak eventTap] in
                _ = eventTap?.start()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        EventTapManager.shared.stop()
    }
}

@main
struct GlideFixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var accessibility = AccessibilityManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            StatusIndicatorView(
                settings: settings,
                accessibility: accessibility,
                isRunning: EventTapManager.shared.isRunning
            )
        }
        .menuBarExtraStyle(.window)
    }
}
