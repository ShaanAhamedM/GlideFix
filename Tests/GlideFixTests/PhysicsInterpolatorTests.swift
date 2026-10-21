import XCTest
import CoreGraphics
@testable import GlideFixCore

final class PhysicsInterpolatorTests: XCTestCase {

    func testPhysicsConvergenceToZero() {
        var recordedEmittedPixels: [(Double, Double)] = []
        let testQueue = DispatchQueue(label: "com.glidefix.test.physics")

        let interpolator = PhysicsInterpolator(queue: testQueue) { dy, dx in
            recordedEmittedPixels.append((dy, dx))
        }

        let stepSize = 40.0
        let damping = 0.85

        // Feed 1 notch
        interpolator.testFeed(deltaY: 1.0, deltaX: 0.0, stepSize: stepSize, dampingFactor: damping)

        // Step physics frame by frame until converged
        var frameCount = 0
        let maxFrames = 100 // At 120Hz, 100 frames is ~830ms, plenty for damping from 40px

        while frameCount < maxFrames {
            interpolator.testStep()
            frameCount += 1

            let (remY, remX) = interpolator.testRemainingDisplacement
            if abs(remY) < 0.001 && abs(remX) < 0.001 {
                break
            }
        }

        // Verify convergence occurred well within max frames
        XCTAssertLessThan(frameCount, maxFrames, "Physics must converge to zero within expected frames")

        let (finalY, finalX) = interpolator.testRemainingDisplacement
        XCTAssertEqual(finalY, 0.0, accuracy: 0.001, "Remaining vertical displacement must be exactly zero")
        XCTAssertEqual(finalX, 0.0, accuracy: 0.001, "Remaining horizontal displacement must be exactly zero")

        // Sum up all emitted pixels to verify displacement conservation
        let totalEmittedY = recordedEmittedPixels.reduce(0.0) { $0 + $1.0 }
        XCTAssertEqual(totalEmittedY, stepSize, accuracy: 1.0, "Total emitted pixels must match target step size")

        // Timer must not be running after convergence
        XCTAssertFalse(interpolator.isRunning, "Timer must be suspended/cancelled after convergence (0% CPU)")
    }

    func testTimerLeakPreventionOnStop() {
        let testQueue = DispatchQueue(label: "com.glidefix.test.timerleak")
        let interpolator = PhysicsInterpolator(queue: testQueue) { _, _ in }

        // Start timer by feeding impulse
        interpolator.testFeed(deltaY: 5.0, deltaX: 0.0, stepSize: 50.0, dampingFactor: 0.88)
        XCTAssertTrue(interpolator.isRunning, "Timer should be running while active impulse is processing")

        // Force stop
        interpolator.stop()

        // Wait brief tick on serial queue
        testQueue.sync {}

        XCTAssertFalse(interpolator.isRunning, "Timer must be cancelled and released on stop(), preventing leaks")
    }

    func testInstantDirectionReversal() {
        var emitted: [(Double, Double)] = []
        let testQueue = DispatchQueue(label: "com.glidefix.test.reversal")
        let interpolator = PhysicsInterpolator(queue: testQueue) { dy, dx in
            emitted.append((dy, dx))
        }

        // User scrolling down (+50px target)
        interpolator.testFeed(deltaY: 1.0, deltaX: 0.0, stepSize: 50.0, dampingFactor: 0.88)
        interpolator.testStep()

        // User immediately flicks in opposite direction (-50px target)
        interpolator.testFeed(deltaY: -1.0, deltaX: 0.0, stepSize: 50.0, dampingFactor: 0.88)

        let (remY, _) = interpolator.testRemainingDisplacement
        XCTAssertLessThan(remY, 0.0, "Momentum must instantly reverse when opposite wheel notch arrives")
    }
}
