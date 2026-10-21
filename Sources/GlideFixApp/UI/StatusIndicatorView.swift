import SwiftUI
import GlideFixCore

public struct StatusIndicatorView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var accessibility: AccessibilityManager
    let isRunning: Bool

    public init(
        settings: AppSettings = .shared,
        accessibility: AccessibilityManager = .shared,
        isRunning: Bool = false
    ) {
        self.settings = settings
        self.accessibility = accessibility
        self.isRunning = isRunning
    }

    private var statusColor: Color {
        if !accessibility.isTrusted {
            return .orange // Amber = Needs Permission
        }
        if !settings.isEnabled || !isRunning {
            return .gray // Gray = Paused / Disabled
        }
        return .green // Green = Active
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 13, weight: .medium))

            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
        }
    }
}
