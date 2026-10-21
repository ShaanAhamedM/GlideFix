import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation

/// Security result from validating a CGEventMask.
public enum EventMaskSecurityResult: Equatable {
    case valid
    case unauthorizedBitsDetected(mask: CGEventMask, unauthorizedBits: CGEventMask)
}

/// Principal security auditor enforcing hardware-level anti-keylogger guarantees,
/// anti-tamper debugger rejection, anti-dylib injection, and circuit-breaker protection.
public final class SecurityAuditor {

    /// Expected strict scroll-only mask (1 << CGEventType.scrollWheel.rawValue = 0x400000)
    public static let scrollWheelMask: CGEventMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

    // MARK: - 1. Strict Event-Mask Isolation

    /// Evaluates whether an event mask is strictly limited to scroll-wheel events.
    /// Hardware-level guarantee that no keyboard or mouse-click bits are ever listened to.
    public static func checkEventMask(_ mask: CGEventMask) -> EventMaskSecurityResult {
        let allowed = scrollWheelMask
        let unauthorized = mask & ~allowed
        if unauthorized != 0 || mask != allowed {
            return .unauthorizedBitsDetected(mask: mask, unauthorizedBits: unauthorized)
        }
        return .valid
    }

    /// Enforces that the event mask is strictly scroll-wheel only.
    /// Triggers fatalError before touching the WindowServer if any unauthorized bit is present.
    public static func enforceEventMask(_ mask: CGEventMask) {
        switch checkEventMask(mask) {
        case .valid:
            break
        case .unauthorizedBitsDetected(let badMask, let unauthorized):
            fatalError("Security violation: Unauthorized CGEventMask bit detected (mask: 0x\(String(badMask, radix: 16)), unauthorized: 0x\(String(unauthorized, radix: 16)))")
        }
    }

    // MARK: - 2. Anti-Dylib Injection Scanner

    /// Scans process environment for any injected dynamic libraries or dyld overrides.
    public static func checkDyldEnvironmentSafety(env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        for (key, value) in env {
            if key.hasPrefix("DYLD_") && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }
        return true
    }

    /// Enforces zero-tolerance against dyld injection. Exits immediately if any DYLD_ variable is present.
    public static func enforceDyldEnvironmentSafety() {
        if !checkDyldEnvironmentSafety() {
            exit(EXIT_FAILURE)
        }
    }

    // MARK: - 3. Anti-Tamper & Debugger Rejection (PT_DENY_ATTACH)

    /// Dynamically invokes ptrace(PT_DENY_ATTACH, 0, 0, 0) in Release mode to prevent process inspection.
    public static func denyDebuggerAttachment() {
        #if !DEBUG
        // PT_DENY_ATTACH = 31
        typealias PTraceFunction = @convention(c) (CInt, pid_t, caddr_t?, CInt) -> CInt
        if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ptrace") {
            let ptrace = unsafeBitCast(sym, to: PTraceFunction.self)
            _ = ptrace(31, 0, nil, 0)
        }
        #endif
    }

    // MARK: - 4. Secure Input Detection

    /// Checks if macOS Secure Event Input is enabled (active password prompt, Keychain dialog, etc.).
    public static func isSecureInputActive() -> Bool {
        return IsSecureEventInputEnabled()
    }

    // MARK: - 5. High-Precision Timing Utilities

    private static var timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Converts mach_absolute_time delta into nanoseconds.
    @inline(__always)
    public static func elapsedNanoseconds(start: UInt64, end: UInt64) -> UInt64 {
        let elapsed = end - start
        return elapsed * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
    }
}

// MARK: - Circuit Breaker

/// Hardware-safety Circuit Breaker.
/// Monitors event tap callback execution time. If callback exceeds 1.5ms for 5 consecutive events,
/// trips and automatically disables the event tap to prevent macOS cursor freeze.
public final class CircuitBreaker {
    /// 1.5 milliseconds = 1,500,000 nanoseconds
    public static let thresholdNanoseconds: UInt64 = 1_500_000
    public static let maxConsecutiveViolations: Int = 5

    private let lock = os_unfair_lock_t.allocate(capacity: 1)
    private var consecutiveViolations: Int = 0
    private var _isTripped: Bool = false

    public var onTrip: (() -> Void)?

    public init() {
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deallocate()
    }

    public var isTripped: Bool {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return _isTripped
    }

    /// Records callback duration. If 5 consecutive violations exceed 1.5ms, trips the breaker.
    @inline(__always)
    public func recordExecution(nanoseconds: UInt64) {
        os_unfair_lock_lock(lock)
        if _isTripped {
            os_unfair_lock_unlock(lock)
            return
        }

        if nanoseconds > Self.thresholdNanoseconds {
            consecutiveViolations += 1
            if consecutiveViolations >= Self.maxConsecutiveViolations {
                _isTripped = true
                os_unfair_lock_unlock(lock)
                onTrip?()
                return
            }
        } else {
            consecutiveViolations = 0
        }
        os_unfair_lock_unlock(lock)
    }

    public func reset() {
        os_unfair_lock_lock(lock)
        _isTripped = false
        consecutiveViolations = 0
        os_unfair_lock_unlock(lock)
    }

    /// Testing helper to inspect current consecutive violation count.
    public var testViolationCount: Int {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return consecutiveViolations
    }
}
