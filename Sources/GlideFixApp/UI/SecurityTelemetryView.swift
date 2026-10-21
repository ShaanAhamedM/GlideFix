import SwiftUI
import GlideFixCore

public struct SecurityTelemetryView: View {
    @ObservedObject var eventTap: EventTapManager = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 13, weight: .bold))

                Text("Security & Kernel Hardening")
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                Text("Audited")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 5) {
                // Row 1: Hardened Runtime & PT_DENY_ATTACH
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10))
                    Text("Hardened Runtime & PT_DENY_ATTACH:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Active")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                // Row 2: Event Scope
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10))
                    Text("Event Scope:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Scroll-Only (0x400000)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                // Row 3: Network & Disk Logging
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10))
                    Text("Network & Disk Logging:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("0% (Air-Gapped)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                // Row 4: Circuit Breaker status (if tripped)
                if eventTap.isCircuitBreakerTripped {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                        Text("Circuit Breaker:")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Spacer()
                        Text("Tripped (Safe Mode)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}
