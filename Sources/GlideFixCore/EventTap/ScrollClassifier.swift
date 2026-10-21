import CoreGraphics
import Foundation

/// Classification of a scroll wheel event.
public enum ScrollClassification: Equatable {
    /// Synthetic event created by GlideFix (tagged with 0x474C4944). Must be passed through.
    case synthetic
    /// Continuous scroll event from a MacBook Trackpad or Apple Magic Mouse. Must be passed through untouched.
    case continuousTrackpad
    /// Discrete, notched scroll tick from an external physical mouse.
    case discreteMouse(deltaY: Int64, deltaX: Int64, fixedPtDeltaY: Double, fixedPtDeltaX: Double)
    /// Event has no delta or is a non-scroll event.
    case ignored
}

public enum ScrollClassifier {
    /// Classifies an incoming CGEvent to determine appropriate handling.
    /// Execution time is strictly sub-microsecond.
    @inline(__always)
    public static func classify(event: CGEvent) -> ScrollClassification {
        // 1. Synthetic event check: Prevent infinite recursion loops
        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == MagicTag.value {
            return .synthetic
        }

        // 2. Device differentiation:
        // Continuous events (scrollWheelEventIsContinuous != 0) originate from Trackpad or Magic Mouse.
        // Discrete events (scrollWheelEventIsContinuous == 0) originate from external physical notched wheels.
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        if isContinuous != 0 {
            return .continuousTrackpad
        }

        // 3. Extract deltas
        let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let fixedPtY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixedPtX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)

        // Non-zero line delta or fixed-point delta indicates active discrete scrolling
        if deltaY != 0 || deltaX != 0 || abs(fixedPtY) > 0.001 || abs(fixedPtX) > 0.001 {
            return .discreteMouse(
                deltaY: deltaY,
                deltaX: deltaX,
                fixedPtDeltaY: fixedPtY,
                fixedPtDeltaX: fixedPtX
            )
        }

        return .ignored
    }
}
