import AppKit
import CoreGraphics
import Foundation

/// Decision outcome for an intercepted scroll event.
public enum EventHandlingDecision: Equatable {
    /// Pass original event through downstream untouched.
    case passThroughUntouched
    /// Swallow discrete event and feed delta to smooth physics interpolator.
    case swallowAndFeedPhysics(deltaY: Double, deltaX: Double)
    /// Invert deltas in-place on discrete event and forward downstream.
    case modifyAndPassThrough(invertedDeltaY: Int64, invertedDeltaX: Int64)
}

/// CoreGraphics event tap manager for intercepting external mouse scroll wheels.
public final class EventTapManager {
    public static let shared = EventTapManager()

    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let lock = NSLock()

    public let interpolator: PhysicsInterpolator
    public let exclusionManager: AppExclusionManager
    public let settings: AppSettings

    @Published public private(set) var isRunning: Bool = false

    public init(
        settings: AppSettings = .shared,
        interpolator: PhysicsInterpolator = PhysicsInterpolator(),
        exclusionManager: AppExclusionManager = .shared
    ) {
        self.settings = settings
        self.interpolator = interpolator
        self.exclusionManager = exclusionManager
    }

    deinit {
        stop()
    }

    /// Starts the CGEventTap on the main runloop in common modes.
    @discardableResult
    public func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard machPort == nil else {
            return true
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            NSLog("[GlideFix] CGEvent.tapCreate failed (check Accessibility permissions).")
            self.isRunning = false
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        self.machPort = tap
        self.runLoopSource = source
        self.isRunning = true
        NSLog("[GlideFix] Event tap successfully started.")
        return true
    }

    /// Stops and removes the event tap and cleans up runloop resources.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = nil
        }

        if let port = machPort {
            CFMachPortInvalidate(port)
            self.machPort = nil
        }

        interpolator.stop()
        self.isRunning = false
        NSLog("[GlideFix] Event tap stopped.")
    }

    /// Watchdog recovery when tap is disabled by macOS due to timeouts or input events.
    public func recoverTap() {
        lock.lock()
        defer { lock.unlock() }
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: true)
            NSLog("[GlideFix] Watchdog: Re-enabled event tap after system timeout.")
        }
    }

    // MARK: - Event Filtering Decision Engine

    /// Pure decision engine for scroll wheel events. Evaluated in < 5 microseconds.
    public static func evaluate(
        event: CGEvent,
        settings: SettingsSnapshot,
        isExcluded: Bool
    ) -> EventHandlingDecision {
        // 1. Synthetic event: Prevent infinite recursion loops
        if event.getIntegerValueField(.eventSourceUserData) == MagicTag.value {
            return .passThroughUntouched
        }

        // 2. Master switch
        if !settings.isEnabled {
            return .passThroughUntouched
        }

        // 3. Trackpad & Magic Mouse continuous events: Pass through untouched
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        if isContinuous != 0 {
            return .passThroughUntouched
        }

        // 4. Extract discrete deltas
        let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let fixedPtY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixedPtX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)

        // Ignore zero-delta events
        if deltaY == 0 && deltaX == 0 && abs(fixedPtY) < 0.001 && abs(fixedPtX) < 0.001 {
            return .passThroughUntouched
        }

        // 5. Excluded app check
        if isExcluded {
            if settings.invertExternalScroll {
                return .modifyAndPassThrough(
                    invertedDeltaY: -deltaY,
                    invertedDeltaX: settings.horizontalScrollSupport ? -deltaX : deltaX
                )
            }
            return .passThroughUntouched
        }

        // 6. Smooth scrolling engine
        if settings.smoothScrollingEnabled {
            var effectiveY = deltaY != 0 ? Double(deltaY) : fixedPtY
            var effectiveX = deltaX != 0 ? Double(deltaX) : fixedPtX

            if settings.invertExternalScroll {
                effectiveY = -effectiveY
                effectiveX = -effectiveX
            }

            return .swallowAndFeedPhysics(deltaY: effectiveY, deltaX: effectiveX)
        }

        // 7. Discrete only (Smooth scrolling disabled)
        if settings.invertExternalScroll {
            return .modifyAndPassThrough(
                invertedDeltaY: -deltaY,
                invertedDeltaX: settings.horizontalScrollSupport ? -deltaX : deltaX
            )
        }

        return .passThroughUntouched
    }
}

// MARK: - C Callback

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()

    // 1. Watchdog Recovery on timeout / user input disable
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        manager.recoverTap()
        return Unmanaged.passUnretained(event)
    }

    guard type == .scrollWheel else {
        return Unmanaged.passUnretained(event)
    }

    let snapshot = manager.settings.currentSnapshot
    let isExcluded = manager.exclusionManager.isFrontmostAppExcluded(in: snapshot.excludedBundleIDs)

    let decision = EventTapManager.evaluate(
        event: event,
        settings: snapshot,
        isExcluded: isExcluded
    )

    switch decision {
    case .passThroughUntouched:
        return Unmanaged.passUnretained(event)

    case .swallowAndFeedPhysics(let dy, let dx):
        manager.interpolator.feed(
            deltaY: dy,
            deltaX: dx,
            stepSize: snapshot.stepSize,
            dampingFactor: snapshot.dampingFactor,
            horizontalEnabled: snapshot.horizontalScrollSupport
        )
        // Swallow discrete event
        return nil

    case .modifyAndPassThrough(let invY, let invX):
        // Invert deltas in place
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: invY)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: invX)

        let fixedPtY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixedPtX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedPtY)
        if snapshot.horizontalScrollSupport {
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixedPtX)
        }

        let ptY = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let ptX = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -ptY)
        if snapshot.horizontalScrollSupport {
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -ptX)
        }

        return Unmanaged.passUnretained(event)
    }
}
