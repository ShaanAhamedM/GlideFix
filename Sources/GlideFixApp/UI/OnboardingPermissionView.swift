import SwiftUI
import GlideFixCore

public struct OnboardingPermissionView: View {
    @ObservedObject var accessibility: AccessibilityManager = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))

                Text("Accessibility Permission Required")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text("macOS requires Accessibility access so GlideFix can intercept external notched mouse events and smooth them.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(action: {
                    accessibility.requestPermissionWithPrompt()
                    accessibility.openSystemSettingsAccessibility()
                }) {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Spacer()

                if accessibility.isPollingActive {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Waiting for permission…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
