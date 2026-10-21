import XCTest
import CoreGraphics
@testable import GlideFixCore

final class AppExclusionTests: XCTestCase {

    func testAppExclusionBypassesSmoothScrolling() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 2,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 2)

        let settings = SettingsSnapshot(
            isEnabled: true,
            invertExternalScroll: true,
            smoothScrollingEnabled: true,
            excludedBundleIDs: ["com.autodesk.AutoCAD"]
        )

        // Case 1: Excluded app active (e.g., AutoCAD) -> Bypasses smoothing
        let decisionExcluded = EventTapManager.evaluate(event: event, settings: settings, isExcluded: true)
        switch decisionExcluded {
        case .modifyAndPassThrough(let invY, _):
            XCTAssertEqual(invY, -2, "Excluded app must bypass smooth scrolling and directly invert")
        default:
            XCTFail("Expected .modifyAndPassThrough, got \(decisionExcluded)")
        }

        // Case 2: Normal non-excluded app active -> Uses smoothing
        let decisionNormal = EventTapManager.evaluate(event: event, settings: settings, isExcluded: false)
        switch decisionNormal {
        case .swallowAndFeedPhysics(let dy, _):
            XCTAssertEqual(dy, -2.0, "Normal app must use smooth physics")
        default:
            XCTFail("Expected .swallowAndFeedPhysics, got \(decisionNormal)")
        }
    }

    func testAppExclusionWithoutInvertPassesUntouched() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 2,
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("Failed to create CGEvent")
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 2)

        let settings = SettingsSnapshot(
            isEnabled: true,
            invertExternalScroll: false, // Invert disabled
            smoothScrollingEnabled: true,
            excludedBundleIDs: ["com.blender.blender"]
        )

        let decision = EventTapManager.evaluate(event: event, settings: settings, isExcluded: true)
        XCTAssertEqual(
            decision,
            .passThroughUntouched,
            "Excluded app with invert OFF must pass discrete event completely untouched"
        )
    }
}
