import AppKit
import SwiftUI
import GlideFixCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let accessibility = AccessibilityManager.shared
        let eventTap = EventTapManager.shared
        let shortcut = GlobalShortcutMonitor.shared

        // Start listening for safety toggle shortcut (Cmd + Option + Shift + M)
        shortcut.start()

        // Check accessibility permissions
        if accessibility.checkIsTrusted() {
            _ = eventTap.start()
        } else {
            // Setup callback for when user grants permission in System Settings
            accessibility.onPermissionGranted = { [weak eventTap] in
                NSLog("[GlideFix] Accessibility permission granted! Starting EventTap...")
                _ = eventTap?.start()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("[GlideFix] Application terminating. Cleaning up resources...")
        EventTapManager.shared.stop()
        GlobalShortcutMonitor.shared.stop()
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
