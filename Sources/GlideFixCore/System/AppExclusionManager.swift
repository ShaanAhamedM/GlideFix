import AppKit
import Foundation

/// Monitors active applications and checks whether the frontmost application is in the exclusion list.
public final class AppExclusionManager {
    public static let shared = AppExclusionManager()

    private let lock = os_unfair_lock_t.allocate(capacity: 1)
    private var _cachedBundleID: String?
    private var _cachedAppName: String?
    private var notificationObserver: NSObjectProtocol?

    public init() {
        lock.initialize(to: os_unfair_lock())
        updateActiveApp()
        setupNotificationObserver()
    }

    deinit {
        if let observer = notificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        lock.deallocate()
    }

    private func setupNotificationObserver() {
        notificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateActiveApp()
        }
    }

    private func updateActiveApp() {
        let app = NSWorkspace.shared.frontmostApplication
        let bundleID = app?.bundleIdentifier
        let localizedName = app?.localizedName

        os_unfair_lock_lock(lock)
        self._cachedBundleID = bundleID
        self._cachedAppName = localizedName
        os_unfair_lock_unlock(lock)
    }

    /// Fast, non-blocking lookup of the frontmost app's bundle identifier (< 1 microsecond).
    public var frontmostBundleID: String? {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return _cachedBundleID
    }

    /// Frontmost app name for UI display.
    public var frontmostAppName: String? {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return _cachedAppName
    }

    /// Checks if the frontmost app matches any bundle ID in the excluded set.
    @inline(__always)
    public func isFrontmostAppExcluded(in excludedIDs: Set<String>) -> Bool {
        guard !excludedIDs.isEmpty else { return false }
        guard let current = frontmostBundleID else { return false }
        return excludedIDs.contains(current)
    }
}
