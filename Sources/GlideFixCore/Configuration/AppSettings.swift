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
        self.stepSize = AppSettings.sanitizeStepSize(stepSize)
        self.dampingFactor = AppSettings.sanitizeDampingFactor(dampingFactor)
        self.horizontalScrollSupport = horizontalScrollSupport
        self.excludedBundleIDs = excludedBundleIDs
    }
}

/// Observable application settings backed by UserDefaults and providing synchronized snapshots.
/// Strictly sanitized against NaN, infinity, and out-of-bounds tampering.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    // Bounds constants
    public static let minStepSize: Double = 5.0
    public static let maxStepSize: Double = 150.0
    public static let defaultStepSize: Double = 45.0

    public static let minDampingFactor: Double = 0.50
    public static let maxDampingFactor: Double = 0.98
    public static let defaultDampingFactor: Double = 0.88

    public static let minDisplacementCap: Double = 100.0
    public static let maxDisplacementCap: Double = 2500.0
    public static let defaultDisplacementCap: Double = 2500.0

    // MARK: - Bounds Sanitizers

    public static func sanitizeStepSize(_ value: Double) -> Double {
        guard !value.isNaN && !value.isInfinite else { return defaultStepSize }
        return max(minStepSize, min(maxStepSize, value))
    }

    public static func sanitizeDampingFactor(_ value: Double) -> Double {
        guard !value.isNaN && !value.isInfinite else { return defaultDampingFactor }
        return max(minDampingFactor, min(maxDampingFactor, value))
    }

    public static func sanitizeDisplacementCap(_ value: Double) -> Double {
        guard !value.isNaN && !value.isInfinite else { return defaultDisplacementCap }
        return max(minDisplacementCap, min(maxDisplacementCap, value))
    }

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
            let sanitized = AppSettings.sanitizeStepSize(stepSize)
            if sanitized != stepSize {
                stepSize = sanitized
                return
            }
            defaults.set(stepSize, forKey: Keys.stepSize)
            updateCachedSnapshot()
        }
    }

    @Published public var dampingFactor: Double {
        didSet {
            let sanitized = AppSettings.sanitizeDampingFactor(dampingFactor)
            if sanitized != dampingFactor {
                dampingFactor = sanitized
                return
            }
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
            Keys.stepSize: AppSettings.defaultStepSize,
            Keys.dampingFactor: AppSettings.defaultDampingFactor,
            Keys.horizontalScrollSupport: true,
            Keys.excludedBundleIDs: []
        ])

        let enabled = defaults.bool(forKey: Keys.isEnabled)
        let invert = defaults.bool(forKey: Keys.invertExternalScroll)
        let smooth = defaults.bool(forKey: Keys.smoothScrollingEnabled)
        let step = AppSettings.sanitizeStepSize(defaults.double(forKey: Keys.stepSize))
        let damp = AppSettings.sanitizeDampingFactor(defaults.double(forKey: Keys.dampingFactor))
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
        stepSize = AppSettings.defaultStepSize
        dampingFactor = AppSettings.defaultDampingFactor
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
            // Strict zero-logging: error discarded
        }
    }
}
