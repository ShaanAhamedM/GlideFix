import XCTest
import CoreGraphics
@testable import GlideFixCore

final class EventTaggingTests: XCTestCase {

    func testSyntheticEventBypassesInterceptor() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: 8,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        // Tag with 0x474C4944 ("GLID")
        event.setIntegerValueField(.eventSourceUserData, value: MagicTag.value)

        let settings = SettingsSnapshot(
            isEnabled: true,
            invertExternalScroll: true,
            smoothScrollingEnabled: true
        )

        let decision = EventTapManager.evaluate(event: event, settings: settings, isExcluded: false)
        XCTAssertEqual(
            decision,
            .passThroughUntouched,
            "Synthetic events tagged with 0x474C4944 must pass through untouched to prevent infinite loops."
        )
    }

    func testTrackpadContinuousEventBypassesInterceptor() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -3,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        // Native trackpad / Magic Mouse event
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

        let settings = SettingsSnapshot(
            isEnabled: true,
            invertExternalScroll: true,
            smoothScrollingEnabled: true
        )

        let decision = EventTapManager.evaluate(event: event, settings: settings, isExcluded: false)
        XCTAssertEqual(
            decision,
            .passThroughUntouched,
            "Trackpad continuous events (isContinuous != 0) must be bypassed untouched."
        )
    }

    func testMasterDisabledBypassesAllEvents() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 1,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 1)

        let settings = SettingsSnapshot(
            isEnabled: false, // Master Disabled
            invertExternalScroll: true,
            smoothScrollingEnabled: true
        )

        let decision = EventTapManager.evaluate(event: event, settings: settings, isExcluded: false)
        XCTAssertEqual(
            decision,
            .passThroughUntouched,
            "When master is disabled, all events must pass through untouched."
        )
    }

    func testDiscreteMouseSwallowedAndInvertedForPhysics() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 1, // 1 notch upward
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 1)

        let settings = SettingsSnapshot(
            isEnabled: true,
            invertExternalScroll: true,
            smoothScrollingEnabled: true
        )

        let decision = EventTapManager.evaluate(event: event, settings: settings, isExcluded: false)
        switch decision {
        case .swallowAndFeedPhysics(let dy, let dx):
            // Inverted: 1 becomes -1
            XCTAssertEqual(dy, -1.0, "Delta must be inverted when invertExternalScroll is true")
            XCTAssertEqual(dx, 0.0)
        default:
            XCTFail("Expected .swallowAndFeedPhysics, got \(decision)")
        }
    }

    func testDiscreteMouseDirectInvertWhenSmoothingDisabled() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 1,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 1)

        let settings = SettingsSnapshot(
            isEnabled: true,
            invertExternalScroll: true,
            smoothScrollingEnabled: false // Smoothing OFF
        )

        let decision = EventTapManager.evaluate(event: event, settings: settings, isExcluded: false)
        switch decision {
        case .modifyAndPassThrough(let invY, _):
            XCTAssertEqual(invY, -1, "Line delta must be directly inverted when smoothing is OFF")
        default:
            XCTFail("Expected .modifyAndPassThrough, got \(decision)")
        }
    }
}
