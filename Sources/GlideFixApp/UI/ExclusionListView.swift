import AppKit
import SwiftUI
import GlideFixCore

public struct ExclusionListView: View {
    @ObservedObject var settings: AppSettings = .shared
    let exclusionManager: AppExclusionManager = .shared

    @State private var manualBundleID: String = ""
    @State private var frontmostName: String?
    @State private var frontmostID: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Exclusions")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Apps listed here bypass smooth scrolling (useful for CAD, 3D modelling, or games).")
                .font(.caption)
                .foregroundColor(.secondary)

            // Quick add frontmost app button
            if let id = frontmostID, !id.isEmpty {
                let isAlreadyExcluded = settings.excludedBundleIDs.contains(id)
                Button(action: {
                    if isAlreadyExcluded {
                        settings.removeExcludedBundleID(id)
                    } else {
                        settings.addExcludedBundleID(id)
                    }
                }) {
                    HStack {
                        Image(systemName: isAlreadyExcluded ? "checkmark.circle.fill" : "plus.circle")
                        Text(isAlreadyExcluded ? "Excluded: \(frontmostName ?? id)" : "Exclude Frontmost: \(frontmostName ?? id)")
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(isAlreadyExcluded ? .secondary : .accentColor)
            }

            // Excluded Apps List
            if settings.excludedBundleIDs.isEmpty {
                Text("No excluded apps. All apps use GlideFix.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button(action: {
                                settings.removeExcludedBundleID(bundleID)
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
                .frame(maxHeight: 100)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(6)
        .onAppear {
            updateFrontmostInfo()
        }
    }

    private func updateFrontmostInfo() {
        self.frontmostID = exclusionManager.frontmostBundleID
        self.frontmostName = exclusionManager.frontmostAppName
    }
}
