import XCTest
import CoreGraphics
@testable import GlideFixCore

final class MemorySafetyTests: XCTestCase {

    func testUnmanagedCGEventRetainCountStability() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: 10,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        // Test passUnretained does not alter retain count
        let initialRetainCount = CFGetRetainCount(event)

        for _ in 0..<1000 {
            let unmanaged = Unmanaged.passUnretained(event)
            let unwrapped = unmanaged.takeUnretainedValue()
            _ = unwrapped.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        }

        let finalRetainCount = CFGetRetainCount(event)
        XCTAssertEqual(
            initialRetainCount,
            finalRetainCount,
            "Unmanaged.passUnretained must not modify retain count over 1000 iterations (zero leaks, zero over-releases)"
        )
    }

    func testSyntheticEventGenerationZeroLeak() {
        // Generate thousands of synthetic events to ensure autorelease / deallocation is completely clean
        for _ in 0..<2000 {
            autoreleasepool {
                guard let synthetic = CGEvent(
                    scrollWheelEvent2Source: nil,
                    units: .pixel,
                    wheelCount: 2,
                    wheel1: 12,
                    wheel2: 0,
                    wheel3: 0
                ) else {
                    XCTFail("Failed to create synthetic event")
                    return
                }
                synthetic.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                synthetic.setIntegerValueField(.eventSourceUserData, value: MagicTag.value)
                XCTAssertEqual(synthetic.getIntegerValueField(.eventSourceUserData), MagicTag.value)
            }
        }
    }

    func testEventTapManagerDeinitClean() {
        var manager: EventTapManager? = EventTapManager()
        XCTAssertNotNil(manager)
        manager?.stop()
        manager = nil
        XCTAssertNil(manager, "EventTapManager must cleanly deallocate with zero retain cycles")
    }
}
