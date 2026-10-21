import SwiftUI
import GlideFixCore

public struct PhysicsControlsView: View {
    @ObservedObject var settings: AppSettings = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step Size Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scroll Step Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(settings.stepSize)) px / notch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $settings.stepSize, in: 15...100, step: 1) {
                    Text("Step Size")
                } minimumValueLabel: {
                    Text("15").font(.caption2).foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("100").font(.caption2).foregroundColor(.secondary)
                }
            }

            // Smoothness / Friction Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Glide Smoothness")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(settings.dampingFactor * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $settings.dampingFactor, in: 0.70...0.96, step: 0.01) {
                    Text("Smoothness")
                } minimumValueLabel: {
                    Text("Snappy").font(.caption2).foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("Buttery").font(.caption2).foregroundColor(.secondary)
                }
            }

            // Horizontal Scroll Toggle
            Toggle(isOn: $settings.horizontalScrollSupport) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smooth Horizontal Scrolling")
                        .font(.subheadline)
                    Text("Interpolates tilt-wheel or horizontal thumb wheels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            // Reset button
            HStack {
                Spacer()
                Button("Reset Physics Defaults") {
                    settings.stepSize = 45.0
                    settings.dampingFactor = 0.88
                    settings.horizontalScrollSupport = true
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(6)
    }
}
