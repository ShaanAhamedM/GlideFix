import AppKit
import SwiftUI
import GlideFixCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        return true
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
    @StateObject private var eventTap = EventTapManager.shared

    init() {
        // 1. Runtime Anti-Dylib Injection Enforcement
        SecurityAuditor.enforceDyldEnvironmentSafety()

        // 2. Kernel Anti-Tamper & Debugger Rejection
        SecurityAuditor.denyDebuggerAttachment()

        let a11y = AccessibilityManager.shared
        let tap = EventTapManager.shared

        // Start event tap if trusted, or setup reactive activation when granted
        if a11y.checkIsTrusted() {
            _ = tap.start()
        } else {
            a11y.onPermissionGranted = { [weak tap] in
                _ = tap?.start()
            }
        }

        // Activate as foreground app on launch so the main window opens with focus
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var statusIconName: String {
        if !accessibility.isTrusted {
            return "exclamationmark.triangle.fill"
        }
        if !settings.isEnabled {
            return "pause.circle.fill"
        }
        return "computermouse.fill"
    }

    var body: some Scene {
        Window("GlideFix — External Mouse Smooth Scrolling", id: "main") {
            MainWindowView()
        }
        .defaultSize(width: 480, height: 620)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContentView()
        } label: {
            Image(systemName: statusIconName)
        }
        .menuBarExtraStyle(.window)
    }
}
