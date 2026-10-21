import XCTest
import CoreGraphics
@testable import GlideFixCore

final class ScrollClassifierTests: XCTestCase {

    func testSyntheticEventClassification() {
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

        // Tag event with MagicTag
        event.setIntegerValueField(.eventSourceUserData, value: MagicTag.value)

        let result = ScrollClassifier.classify(event: event)
        XCTAssertEqual(result, .synthetic, "Synthetic tagged events must be classified as .synthetic")
    }

    func testTrackpadContinuousEventClassification() {
        guard let event = CGEvent(
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

        // Mark event as continuous (trackpad / magic mouse)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

        let result = ScrollClassifier.classify(event: event)
        XCTAssertEqual(result, .continuousTrackpad, "Trackpad continuous events must be classified as .continuousTrackpad")
    }

    func testDiscreteMouseNotchedWheelClassification() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: -1, // 1 notch downwards
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -1)

        let result = ScrollClassifier.classify(event: event)
        switch result {
        case .discreteMouse(let dy, _, _, _):
            XCTAssertEqual(dy, -1, "Discrete tick delta must be captured")
        default:
            XCTFail("Expected .discreteMouse, got \(result)")
        }
    }

    func testZeroDeltaIgnored() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 0)

        let result = ScrollClassifier.classify(event: event)
        XCTAssertEqual(result, .ignored, "Zero delta scroll event must be ignored")
    }
}
