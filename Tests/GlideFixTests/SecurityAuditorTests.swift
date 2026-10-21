import XCTest
import CoreGraphics
@testable import GlideFixCore

final class SecurityAuditorTests: XCTestCase {

    // MARK: - 1. Event Mask Validator Tests

    func testEventMaskValidatorAcceptsExactScrollWheelMask() {
        let exactMask = SecurityAuditor.scrollWheelMask
        let result = SecurityAuditor.checkEventMask(exactMask)
        XCTAssertEqual(result, .valid, "Strict scroll-wheel mask (0x400000) must be accepted")
    }

    func testEventMaskValidatorRejectsKeyboardBits() {
        // Bit positions: keyDown = 10, keyUp = 11, flagsChanged = 12
        let keyboardBits: [UInt32] = [10, 11, 12]

        for bit in keyboardBits {
            let corruptedMask = SecurityAuditor.scrollWheelMask | CGEventMask(1 << bit)
            let result = SecurityAuditor.checkEventMask(corruptedMask)
            switch result {
            case .unauthorizedBitsDetected(_, let unauthorized):
                XCTAssertEqual(unauthorized, CGEventMask(1 << bit), "Must reject keyboard bit \(bit)")
            default:
                XCTFail("Event mask validator failed to reject keyboard bit \(bit)")
            }
        }
    }

    func testEventMaskValidatorRejectsMouseClickAndMotionBits() {
        // Bits: leftMouseDown = 1, leftMouseUp = 2, rightMouseDown = 3, mouseMoved = 5
        let mouseBits: [UInt32] = [1, 2, 3, 4, 5, 6, 7]

        for bit in mouseBits {
            let corruptedMask = SecurityAuditor.scrollWheelMask | CGEventMask(1 << bit)
            let result = SecurityAuditor.checkEventMask(corruptedMask)
            switch result {
            case .unauthorizedBitsDetected:
                break // Expected
            default:
                XCTFail("Event mask validator failed to reject mouse bit \(bit)")
            }
        }
    }

    // MARK: - 2. Anti-Dylib Injection Scanner Tests

    func testDyldScannerDetectsInjectedVariables() {
        let cleanEnv = [
            "PATH": "/usr/bin:/bin",
            "HOME": "/Users/user",
            "SHELL": "/bin/zsh"
        ]
        XCTAssertTrue(
            SecurityAuditor.checkDyldEnvironmentSafety(env: cleanEnv),
            "Clean environment must be approved"
        )

        let maliciousEnvs = [
            ["DYLD_INSERT_LIBRARIES": "/tmp/evil.dylib"],
            ["DYLD_FRAMEWORK_PATH": "/tmp"],
            ["DYLD_LIBRARY_PATH": "/tmp"],
            ["DYLD_PRINT_LIBRARIES": "1"]
        ]

        for env in maliciousEnvs {
            XCTAssertFalse(
                SecurityAuditor.checkDyldEnvironmentSafety(env: env),
                "Scanner must detect injected dyld variable: \(env.keys.first ?? "")"
            )
        }
    }

    // MARK: - 3. Bounds Clamping & NaN/Infinity Sanitization Tests

    func testPreferenceBoundsClampingAndNaNSanitization() {
        // Step size sanitization
        XCTAssertEqual(AppSettings.sanitizeStepSize(45.0), 45.0)
        XCTAssertEqual(AppSettings.sanitizeStepSize(1.0), AppSettings.minStepSize)
        XCTAssertEqual(AppSettings.sanitizeStepSize(999.0), AppSettings.maxStepSize)
        XCTAssertEqual(AppSettings.sanitizeStepSize(-50.0), AppSettings.minStepSize)
        XCTAssertEqual(AppSettings.sanitizeStepSize(.nan), AppSettings.defaultStepSize)
        XCTAssertEqual(AppSettings.sanitizeStepSize(.infinity), AppSettings.defaultStepSize)
        XCTAssertEqual(AppSettings.sanitizeStepSize(-.infinity), AppSettings.defaultStepSize)

        // Damping factor sanitization
        XCTAssertEqual(AppSettings.sanitizeDampingFactor(0.88), 0.88)
        XCTAssertEqual(AppSettings.sanitizeDampingFactor(0.10), AppSettings.minDampingFactor)
        XCTAssertEqual(AppSettings.sanitizeDampingFactor(0.999), AppSettings.maxDampingFactor)
        XCTAssertEqual(AppSettings.sanitizeDampingFactor(.nan), AppSettings.defaultDampingFactor)
        XCTAssertEqual(AppSettings.sanitizeDampingFactor(.infinity), AppSettings.defaultDampingFactor)

        // Displacement cap sanitization
        XCTAssertEqual(AppSettings.sanitizeDisplacementCap(2500.0), 2500.0)
        XCTAssertEqual(AppSettings.sanitizeDisplacementCap(10.0), AppSettings.minDisplacementCap)
        XCTAssertEqual(AppSettings.sanitizeDisplacementCap(100000.0), AppSettings.maxDisplacementCap)
        XCTAssertEqual(AppSettings.sanitizeDisplacementCap(.nan), AppSettings.defaultDisplacementCap)
    }

    func testPhysicsLoopDoesNotCrashOnNaNDeltas() {
        let queue = DispatchQueue(label: "com.glidefix.test.nan")
        var emitted: [(Double, Double)] = []
        let interpolator = PhysicsInterpolator(queue: queue) { dy, dx in
            emitted.append((dy, dx))
        }

        // Feed corrupted NaN and infinite values
        interpolator.testFeed(deltaY: .nan, deltaX: 0.0, stepSize: 45.0, dampingFactor: 0.88)
        interpolator.testFeed(deltaY: .infinity, deltaX: 0.0, stepSize: 45.0, dampingFactor: 0.88)
        interpolator.testFeed(deltaY: 0.0, deltaX: -.infinity, stepSize: 45.0, dampingFactor: 0.88)

        // Verify remaining displacement remains zero and timer is not stuck
        let (remY, remX) = interpolator.testRemainingDisplacement
        XCTAssertEqual(remY, 0.0)
        XCTAssertEqual(remX, 0.0)
        XCTAssertEqual(emitted.count, 0, "Corrupted NaN deltas must be swallowed safely")
    }

    // MARK: - 4. Sub-50-Microsecond Latency Benchmark Tests

    func testTrackpadAndSyntheticEventsBypassedUnder50Microseconds() {
        guard let trackpadEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: 5,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }
        trackpadEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

        guard let syntheticEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: 5,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }
        syntheticEvent.setIntegerValueField(.eventSourceUserData, value: MagicTag.value)

        let settings = SettingsSnapshot()

        // Benchmark Trackpad Event decision duration
        for _ in 0..<100 {
            let start = mach_absolute_time()
            let decision = EventTapManager.evaluate(
                event: trackpadEvent,
                settings: settings,
                isExcluded: false,
                isSecureInputActive: false
            )
            let end = mach_absolute_time()
            let elapsedNs = SecurityAuditor.elapsedNanoseconds(start: start, end: end)

            XCTAssertEqual(decision, .passThroughUntouched)
            // 50 microseconds = 50,000 nanoseconds
            XCTAssertLessThan(
                elapsedNs,
                50_000,
                "Trackpad event evaluation must be faster than 50 microseconds (took \(elapsedNs) ns)"
            )
        }

        // Benchmark Synthetic Event decision duration
        for _ in 0..<100 {
            let start = mach_absolute_time()
            let decision = EventTapManager.evaluate(
                event: syntheticEvent,
                settings: settings,
                isExcluded: false,
                isSecureInputActive: false
            )
            let end = mach_absolute_time()
            let elapsedNs = SecurityAuditor.elapsedNanoseconds(start: start, end: end)

            XCTAssertEqual(decision, .passThroughUntouched)
            XCTAssertLessThan(
                elapsedNs,
                50_000,
                "Synthetic event evaluation must be faster than 50 microseconds (took \(elapsedNs) ns)"
            )
        }
    }

    // MARK: - 5. Circuit Breaker Tests

    func testCircuitBreakerTripsAfterFiveConsecutiveSlowExecutions() {
        let circuitBreaker = CircuitBreaker()
        var tripCallbackInvoked = false
        circuitBreaker.onTrip = {
            tripCallbackInvoked = true
        }

        // 4 consecutive slow executions (exceeding 1.5ms threshold)
        for i in 1...4 {
            circuitBreaker.recordExecution(nanoseconds: 2_000_000)
            XCTAssertFalse(circuitBreaker.isTripped)
            XCTAssertEqual(circuitBreaker.testViolationCount, i)
        }

        // 5th consecutive slow execution trips the circuit breaker
        circuitBreaker.recordExecution(nanoseconds: 2_000_000)
        XCTAssertTrue(circuitBreaker.isTripped, "Circuit breaker must trip after 5 consecutive slow executions")
        XCTAssertTrue(tripCallbackInvoked)

        // Reset
        circuitBreaker.reset()
        XCTAssertFalse(circuitBreaker.isTripped)
        XCTAssertEqual(circuitBreaker.testViolationCount, 0)
    }

    func testCircuitBreakerResetsOnFastExecution() {
        let circuitBreaker = CircuitBreaker()

        // 3 consecutive slow executions
        circuitBreaker.recordExecution(nanoseconds: 2_000_000)
        circuitBreaker.recordExecution(nanoseconds: 2_000_000)
        circuitBreaker.recordExecution(nanoseconds: 2_000_000)
        XCTAssertEqual(circuitBreaker.testViolationCount, 3)

        // A fast execution (< 1.5ms) resets the consecutive count
        circuitBreaker.recordExecution(nanoseconds: 500_000)
        XCTAssertEqual(circuitBreaker.testViolationCount, 0)
        XCTAssertFalse(circuitBreaker.isTripped)
    }
}
