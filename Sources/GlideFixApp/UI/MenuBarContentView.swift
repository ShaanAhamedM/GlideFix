import SwiftUI
import GlideFixCore

public struct MenuBarContentView: View {
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var accessibility: AccessibilityManager = .shared
    let eventTapManager: EventTapManager = .shared

    public init() {}

    private var statusDescription: (text: String, color: Color) {
        if !accessibility.isTrusted {
            return ("Needs Permission", .orange)
        }
        if !settings.isEnabled {
            return ("Paused", .gray)
        }
        return ("Active", .green)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)

                    Text("GlideFix")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Spacer()

                // Live Status Pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusDescription.color)
                        .frame(width: 7, height: 7)

                    Text(statusDescription.text)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusDescription.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusDescription.color.opacity(0.12))
                .cornerRadius(12)
            }

            // Onboarding Warning Banner (if permission missing)
            if !accessibility.isTrusted {
                OnboardingPermissionView()
            }

            // Master Enable / Pause Toggle
            Toggle(isOn: $settings.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Master Engine")
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("Enable or pause GlideFix scrolling")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!accessibility.isTrusted)

            Divider()

            // External Mouse Direction Inversion
            Toggle(isOn: $settings.invertExternalScroll) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invert External Mouse Scroll")
                        .font(.body)
                    Text("Keeps MacBook Trackpad natural while inverting external mice")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!settings.isEnabled || !accessibility.isTrusted)

            // Smooth Scrolling Engine Toggle
            Toggle(isOn: $settings.smoothScrollingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smooth Scrolling Engine")
                        .font(.body)
                    Text("Converts discrete notched steps into 120Hz continuous momentum")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!settings.isEnabled || !accessibility.isTrusted)

            // Physics Tuning Controls
            if settings.smoothScrollingEnabled && settings.isEnabled && accessibility.isTrusted {
                PhysicsControlsView()
            }

            // App Exclusions
            if settings.isEnabled && accessibility.isTrusted {
                ExclusionListView()
            }

            // Security & Kernel Hardening Live Telemetry Badge
            SecurityTelemetryView()

            Divider()

            // System Options & Footer
            HStack {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .font(.caption)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
