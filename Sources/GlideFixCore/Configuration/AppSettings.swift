import Foundation
import Combine
import ServiceManagement

/// Immutable snapshot of settings for ultra-low latency reads in the CGEventTap callback.
public struct SettingsSnapshot: Sendable, Equatable {
    public let isEnabled: Bool
    public let invertExternalScroll: Bool
    public let smoothScrollingEnabled: Bool
    public let stepSize: Double
    public let dampingFactor: Double
    public let horizontalScrollSupport: Bool
    public let excludedBundleIDs: Set<String>

    public init(
        isEnabled: Bool = true,
        invertExternalScroll: Bool = true,
        smoothScrollingEnabled: Bool = true,
        stepSize: Double = 45.0,
        dampingFactor: Double = 0.88,
        horizontalScrollSupport: Bool = true,
        excludedBundleIDs: Set<String> = []
    ) {
        self.isEnabled = isEnabled
        self.invertExternalScroll = invertExternalScroll
        self.smoothScrollingEnabled = smoothScrollingEnabled
        self.stepSize = stepSize
        self.dampingFactor = dampingFactor
        self.horizontalScrollSupport = horizontalScrollSupport
        self.excludedBundleIDs = excludedBundleIDs
    }
}

/// Observable application settings backed by UserDefaults and providing synchronized snapshots.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private enum Keys {
        static let isEnabled = "com.glidefix.isEnabled"
        static let invertExternalScroll = "com.glidefix.invertExternalScroll"
        static let smoothScrollingEnabled = "com.glidefix.smoothScrollingEnabled"
        static let stepSize = "com.glidefix.stepSize"
        static let dampingFactor = "com.glidefix.dampingFactor"
        static let horizontalScrollSupport = "com.glidefix.horizontalScrollSupport"
        static let excludedBundleIDs = "com.glidefix.excludedBundleIDs"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var _cachedSnapshot: SettingsSnapshot

    @Published public var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            updateCachedSnapshot()
        }
    }

    @Published public var invertExternalScroll: Bool {
        didSet {
            defaults.set(invertExternalScroll, forKey: Keys.invertExternalScroll)
            updateCachedSnapshot()
        }
    }

    @Published public var smoothScrollingEnabled: Bool {
        didSet {
            defaults.set(smoothScrollingEnabled, forKey: Keys.smoothScrollingEnabled)
            updateCachedSnapshot()
        }
    }

    @Published public var stepSize: Double {
        didSet {
            defaults.set(stepSize, forKey: Keys.stepSize)
            updateCachedSnapshot()
        }
    }

    @Published public var dampingFactor: Double {
        didSet {
            defaults.set(dampingFactor, forKey: Keys.dampingFactor)
            updateCachedSnapshot()
        }
    }

    @Published public var horizontalScrollSupport: Bool {
        didSet {
            defaults.set(horizontalScrollSupport, forKey: Keys.horizontalScrollSupport)
            updateCachedSnapshot()
        }
    }

    @Published public var excludedBundleIDs: [String] {
        didSet {
            defaults.set(excludedBundleIDs, forKey: Keys.excludedBundleIDs)
            updateCachedSnapshot()
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Register default values
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.invertExternalScroll: true,
            Keys.smoothScrollingEnabled: true,
            Keys.stepSize: 45.0,
            Keys.dampingFactor: 0.88,
            Keys.horizontalScrollSupport: true,
            Keys.excludedBundleIDs: []
        ])

        let enabled = defaults.bool(forKey: Keys.isEnabled)
        let invert = defaults.bool(forKey: Keys.invertExternalScroll)
        let smooth = defaults.bool(forKey: Keys.smoothScrollingEnabled)
        let step = defaults.double(forKey: Keys.stepSize) > 0 ? defaults.double(forKey: Keys.stepSize) : 45.0
        let damp = defaults.double(forKey: Keys.dampingFactor) > 0 ? defaults.double(forKey: Keys.dampingFactor) : 0.88
        let horiz = defaults.bool(forKey: Keys.horizontalScrollSupport)
        let excluded = defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? []

        self.isEnabled = enabled
        self.invertExternalScroll = invert
        self.smoothScrollingEnabled = smooth
        self.stepSize = step
        self.dampingFactor = damp
        self.horizontalScrollSupport = horiz
        self.excludedBundleIDs = excluded

        let loginStatus = SMAppService.mainApp.status == .enabled
        self.launchAtLogin = loginStatus

        self._cachedSnapshot = SettingsSnapshot(
            isEnabled: enabled,
            invertExternalScroll: invert,
            smoothScrollingEnabled: smooth,
            stepSize: step,
            dampingFactor: damp,
            horizontalScrollSupport: horiz,
            excludedBundleIDs: Set(excluded)
        )
    }

    /// Returns an immutable, thread-safe snapshot of settings for real-time event filtering.
    public var currentSnapshot: SettingsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return _cachedSnapshot
    }

    private func updateCachedSnapshot() {
        lock.lock()
        _cachedSnapshot = SettingsSnapshot(
            isEnabled: isEnabled,
            invertExternalScroll: invertExternalScroll,
            smoothScrollingEnabled: smoothScrollingEnabled,
            stepSize: stepSize,
            dampingFactor: dampingFactor,
            horizontalScrollSupport: horizontalScrollSupport,
            excludedBundleIDs: Set(excludedBundleIDs)
        )
        lock.unlock()
    }

    public func addExcludedBundleID(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !excludedBundleIDs.contains(trimmed) else { return }
        excludedBundleIDs.append(trimmed)
    }

    public func removeExcludedBundleID(_ bundleID: String) {
        excludedBundleIDs.removeAll { $0 == bundleID }
    }

    public func resetToDefaults() {
        isEnabled = true
        invertExternalScroll = true
        smoothScrollingEnabled = true
        stepSize = 45.0
        dampingFactor = 0.88
        horizontalScrollSupport = true
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("[GlideFix] Failed to set launch at login: \(error)")
        }
    }
}
