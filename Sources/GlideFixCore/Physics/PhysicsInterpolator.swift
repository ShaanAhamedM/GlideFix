import CoreGraphics
import Foundation
import QuartzCore

/// High-performance, 120Hz physics-based momentum scroll interpolator.
/// Hardened against NaN propagation, infinite values, and integer overflows.
public final class PhysicsInterpolator {
    public typealias ScrollEventEmitter = (Double, Double) -> Void

    private let queue: DispatchQueue
    private var timer: DispatchSourceTimer?
    private let emitter: ScrollEventEmitter

    // Physics state (accessed strictly on `queue`)
    private var targetRemainingY: Double = 0.0
    private var targetRemainingX: Double = 0.0
    private var fractionalAccumulatorY: Double = 0.0
    private var fractionalAccumulatorX: Double = 0.0
    private var currentDampingFactor: Double = AppSettings.defaultDampingFactor
    private var lastTickTime: TimeInterval = 0

    // Convergence threshold: below 0.5 pixels remaining, finish and suspend timer
    public static let convergenceThreshold: Double = 0.5

    /// Frame interval for 120Hz display refresh (8,333,333 nanoseconds ≈ 8.33ms)
    public static let frameIntervalNanoseconds: DispatchTimeInterval = .nanoseconds(8_333_333)

    public init(
        queue: DispatchQueue = DispatchQueue(label: "com.glidefix.physics", qos: .userInteractive),
        emitter: ScrollEventEmitter? = nil
    ) {
        self.queue = queue
        self.emitter = emitter ?? PhysicsInterpolator.defaultScrollEmitter
    }

    deinit {
        stopSync()
    }

    /// Feeds discrete notched delta values into the momentum accumulator asynchronously.
    /// Input deltas are strictly verified for NaN and infinite bounds.
    public func feed(
        deltaY: Double,
        deltaX: Double,
        stepSize: Double,
        dampingFactor: Double,
        horizontalEnabled: Bool
    ) {
        guard !deltaY.isNaN && !deltaY.isInfinite, !deltaX.isNaN && !deltaX.isInfinite else {
            return
        }

        queue.async { [weak self] in
            self?.processFeed(
                deltaY: deltaY,
                deltaX: horizontalEnabled ? deltaX : 0.0,
                stepSize: stepSize,
                dampingFactor: dampingFactor
            )
        }
    }

    /// Internal logic with strict bounds clamping and momentum acceleration.
    private func processFeed(
        deltaY: Double,
        deltaX: Double,
        stepSize: Double,
        dampingFactor: Double
    ) {
        guard !deltaY.isNaN && !deltaY.isInfinite, !deltaX.isNaN && !deltaX.isInfinite else {
            return
        }

        let safeStep = AppSettings.sanitizeStepSize(stepSize)
        let safeDamping = AppSettings.sanitizeDampingFactor(dampingFactor)
        self.currentDampingFactor = safeDamping

        let now = CACurrentMediaTime()
        let elapsed = now - lastTickTime
        lastTickTime = now

        // Calculate velocity multiplier for rapid flicks (momentum acceleration)
        let speedMultiplier: Double
        if elapsed < 0.08 && elapsed > 0.001 {
            speedMultiplier = min(2.2, 1.0 + (0.08 - elapsed) * 15.0)
        } else {
            speedMultiplier = 1.0
        }

        let impulseY = deltaY * safeStep * speedMultiplier
        let impulseX = deltaX * safeStep * speedMultiplier

        // Instant directional reversal: if user scrolls in opposite direction, cancel prior momentum
        if (impulseY > 0 && targetRemainingY < 0) || (impulseY < 0 && targetRemainingY > 0) {
            targetRemainingY = 0.0
            fractionalAccumulatorY = 0.0
        }
        if (impulseX > 0 && targetRemainingX < 0) || (impulseX < 0 && targetRemainingX > 0) {
            targetRemainingX = 0.0
            fractionalAccumulatorX = 0.0
        }

        // Apply impulse and clamp to max displacement cap (prevents integer overflow)
        let cap = AppSettings.maxDisplacementCap
        targetRemainingY = max(-cap, min(cap, targetRemainingY + impulseY))
        targetRemainingX = max(-cap, min(cap, targetRemainingX + impulseX))

        startTimerIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }

        let newTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        newTimer.schedule(
            deadline: .now() + PhysicsInterpolator.frameIntervalNanoseconds,
            repeating: PhysicsInterpolator.frameIntervalNanoseconds,
            leeway: .microseconds(400)
        )
        newTimer.setEventHandler { [weak self] in
            self?.tick()
        }
        newTimer.resume()
        self.timer = newTimer
    }

    /// Single interpolation frame step at 120Hz.
    private func tick() {
        let stepFraction = 1.0 - currentDampingFactor

        let frameY = targetRemainingY * stepFraction
        targetRemainingY -= frameY
        fractionalAccumulatorY += frameY

        let frameX = targetRemainingX * stepFraction
        targetRemainingX -= frameX
        fractionalAccumulatorX += frameX

        let pixelDeltaY = round(fractionalAccumulatorY)
        fractionalAccumulatorY -= pixelDeltaY

        let pixelDeltaX = round(fractionalAccumulatorX)
        fractionalAccumulatorX -= pixelDeltaX

        if pixelDeltaY != 0 || pixelDeltaX != 0 {
            emitter(pixelDeltaY, pixelDeltaX)
        }

        // Convergence check: when remaining momentum is beneath threshold, flush remainder and sleep
        if abs(targetRemainingY) < Self.convergenceThreshold && abs(targetRemainingX) < Self.convergenceThreshold {
            let finalY = round(targetRemainingY + fractionalAccumulatorY)
            let finalX = round(targetRemainingX + fractionalAccumulatorX)
            if finalY != 0 || finalX != 0 {
                emitter(finalY, finalX)
            }

            // Reset state
            targetRemainingY = 0.0
            targetRemainingX = 0.0
            fractionalAccumulatorY = 0.0
            fractionalAccumulatorX = 0.0

            // Suspend / cancel timer to guarantee 0.0% idle CPU
            stopTimer()
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    public func stop() {
        queue.async { [weak self] in
            self?.stopTimer()
            self?.targetRemainingY = 0.0
            self?.targetRemainingX = 0.0
            self?.fractionalAccumulatorY = 0.0
            self?.fractionalAccumulatorX = 0.0
        }
    }

    private func stopSync() {
        queue.sync {
            self.stopTimer()
        }
    }

    /// Default scroll emitter: constructs a synthetic continuous pixel CGEvent with MagicTag
    public static let defaultScrollEmitter: ScrollEventEmitter = { pixelDeltaY, pixelDeltaX in
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(pixelDeltaY),
            wheel2: Int32(pixelDeltaX),
            wheel3: 0
        ) else { return }

        // Continuous flag guarantees macOS recognizes momentum stream
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        // Tag with magic value to bypass event tap recursion
        event.setIntegerValueField(.eventSourceUserData, value: MagicTag.value)
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Testing Helpers

    public func testStep() {
        queue.sync {
            self.tick()
        }
    }

    public func testFeed(deltaY: Double, deltaX: Double, stepSize: Double, dampingFactor: Double) {
        queue.sync {
            self.processFeed(deltaY: deltaY, deltaX: deltaX, stepSize: stepSize, dampingFactor: dampingFactor)
        }
    }

    public var isRunning: Bool {
        queue.sync {
            timer != nil
        }
    }

    public var testRemainingDisplacement: (Double, Double) {
        queue.sync {
            (self.targetRemainingY, self.targetRemainingX)
        }
    }
}
