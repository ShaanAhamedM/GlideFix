import SwiftUI
import GlideFixCore

public struct OnboardingPermissionView: View {
    @ObservedObject var accessibility: AccessibilityManager = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))

                Text("Accessibility Permission Required")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if accessibility.isPollingActive {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Live checking…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text("macOS requires Accessibility access so GlideFix can intercept external notched mouse events and smooth them.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Primary action buttons
            HStack(spacing: 8) {
                Button(action: {
                    accessibility.requestPermissionWithPrompt()
                    accessibility.openSystemSettingsAccessibility()
                }) {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(action: {
                    _ = accessibility.refreshTrustStatus()
                }) {
                    Label("Check Permission", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    AccessibilityManager.relaunchApplication()
                }) {
                    Label("Restart GlideFix", systemImage: "power")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }

            // Tip for the macOS TCC caching behavior
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 1)

                Text("If already toggled ON in System Settings, click 'Check Permission' above, or toggle the switch OFF and back ON in System Settings.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(6)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
