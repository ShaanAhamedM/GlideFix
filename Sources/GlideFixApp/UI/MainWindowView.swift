import AppKit
import SwiftUI
import GlideFixCore

public struct MainWindowView: View {
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var accessibility: AccessibilityManager = .shared
    @ObservedObject var eventTap: EventTapManager = .shared

    public init() {}

    private var statusDescription: (title: String, subtitle: String, color: Color) {
        if !accessibility.isTrusted {
            return (
                "Accessibility Permission Needed",
                "GlideFix needs Accessibility access to smooth external mouse scrolling.",
                .orange
            )
        }
        if !settings.isEnabled {
            return (
                "GlideFix is Paused",
                "Scrolling interception is temporarily paused.",
                .gray
            )
        }
        return (
            "GlideFix is Active & Protecting Your Scroll",
            "Discrete external mouse ticks are smoothly interpolated at 120Hz.",
            .green
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header with App Icon and Status
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(statusDescription.color.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: "computermouse.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(statusDescription.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("GlideFix")
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()

                            // Status Pill
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(statusDescription.color)
                                    .frame(width: 8, height: 8)
                                Text(accessibility.isTrusted ? (settings.isEnabled ? "Active" : "Paused") : "Permission Needed")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusDescription.color)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(statusDescription.color.opacity(0.12))
                            .cornerRadius(12)
                        }

                        Text(statusDescription.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 4)

                // Onboarding Banner if permission missing
                if !accessibility.isTrusted {
                    OnboardingPermissionView()
                }

                // Master Toggle
                Toggle(isOn: $settings.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Master Engine")
                            .font(.headline)
                        Text("Enable or pause all GlideFix mouse corrections")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(!accessibility.isTrusted)

                Divider()

                // Core Controls
                VStack(alignment: .leading, spacing: 14) {
                    Text("Scrolling Options")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Toggle(isOn: $settings.invertExternalScroll) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invert External Mouse Scroll")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Keeps MacBook Trackpad natural while inverting external mouse wheel direction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!settings.isEnabled || !accessibility.isTrusted)

                    Toggle(isOn: $settings.smoothScrollingEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smooth Momentum Engine")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Converts discrete notched steps into 120Hz continuous momentum physics")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!settings.isEnabled || !accessibility.isTrusted)
                }

                // Physics Controls (when smooth is enabled)
                if settings.smoothScrollingEnabled && settings.isEnabled && accessibility.isTrusted {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Physics Tuning")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        PhysicsControlsView()
                    }
                }

                // App Exclusions
                if settings.isEnabled && accessibility.isTrusted {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Application Exclusions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ExclusionListView()
                    }
                }

                // Security Telemetry Badge
                VStack(alignment: .leading, spacing: 6) {
                    Text("Security Architecture")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    SecurityTelemetryView()
                }

                Divider()

                // Footer
                HStack {
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                        .font(.subheadline)
                        .toggleStyle(.checkbox)

                    Spacer()

                    Button("Quit GlideFix") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.bordered)
                }

                // Background notification note
                Text("GlideFix also runs in your Menu Bar (top-right). Closing this window keeps GlideFix active in the background.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(width: 460, height: 600)
    }
}
