//
//  ModuleDownloadLiveActivity.swift
//  XBibleWidgets
//
//  Created by Zoe Brooklyn on 9/28/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Design tokens

private enum LATokens {
    static let iconSize: CGFloat        = 22
    static let compactIconSize: CGFloat = 14
    static let barHeight: CGFloat       = 6
    static let corner: CGFloat          = 10
}

// MARK: - Widget

struct ModuleDownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ModuleDownloadAttributes.self) { context in
            LockScreenView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // ── Leading: icon + module name
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        statusGlyph(for: context.state, size: 16)
                        Text(context.attributes.moduleName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // ── Trailing: percentage, monospaced so it doesn't wiggle
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percentString(context.state.progress))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: context.state.progress))
                }

                // ── Bottom: progress bar + status/bytes
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        progressBar(for: context.state)

                        HStack(spacing: 6) {
                            Text(context.state.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            if context.state.totalBytes > 0 {
                                Text(byteString(context.state))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                statusGlyph(for: context.state, size: 14)
            } compactTrailing: {
                Text(percentString(context.state.progress))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText(value: context.state.progress))
            } minimal: {
                statusGlyph(for: context.state, size: 14)
            }
            .keylineTint(.accentColor)
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let context: ActivityViewContext<ModuleDownloadAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 10) {
                statusGlyph(for: context.state, size: 22)
                    .frame(width: LATokens.iconSize, height: LATokens.iconSize)

                VStack(alignment: .leading, spacing: 1) {
                    Text(context.attributes.moduleName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(context.attributes.sourceName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(percentString(context.state.progress))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText(value: context.state.progress))
            }

            // Progress bar
            progressBar(for: context.state)

            // Footer: status + bytes
            HStack(spacing: 6) {
                Text(context.state.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if context.state.totalBytes > 0 {
                    Text(byteString(context.state))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Reusable sub-views

@ViewBuilder
private func progressBar(for state: ModuleDownloadAttributes.ContentState) -> some View {
    ProgressView(value: state.progress)
        .progressViewStyle(.linear)
        .tint(.accentColor)
        .frame(height: LATokens.barHeight)
        .clipShape(Capsule())
        .animation(.smooth(duration: 0.35), value: state.progress)
}

/// A glyph that reflects the download status.
/// Downloads pulse; completions pop a checkmark; failures show an
/// exclamation. Cancel shows an x.
@ViewBuilder
private func statusGlyph(
    for state: ModuleDownloadAttributes.ContentState,
    size: CGFloat
) -> some View {
    let symbol: String = {
        switch state.status {
        case "Done":      return "checkmark.circle.fill"
        case "Failed":    return "exclamationmark.triangle.fill"
        case "Cancelled": return "xmark.circle.fill"
        case "Preparing": return "hourglass"
        default:          return "arrow.down.circle.fill"
        }
    }()

    let color: Color = {
        switch state.status {
        case "Done":      return .green
        case "Failed":    return .orange
        case "Cancelled": return .secondary
        default:          return .accentColor
        }
    }()

    Image(systemName: symbol)
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(color)
        .symbolEffect(
            .pulse,
            options: .repeating,
            isActive: state.status == "Downloading" || state.status == "Preparing"
        )
        .contentTransition(.symbolEffect(.replace))
        .animation(.snappy(duration: 0.3), value: state.status)
}

// MARK: - Formatting

private func percentString(_ p: Double) -> String {
    "\(Int((p * 100).rounded()))%"
}

private func byteString(_ state: ModuleDownloadAttributes.ContentState) -> String {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useKB, .useMB, .useGB]
    f.countStyle = .file
    return "\(f.string(fromByteCount: state.downloadedBytes)) / \(f.string(fromByteCount: state.totalBytes))"
}

// MARK: - Previews

#Preview("Live Activity", as: .content, using: ModuleDownloadAttributes(
    moduleName: "King James Version",
    sourceName: "CrossWire"
)) {
    ModuleDownloadLiveActivity()
} contentStates: {
    ModuleDownloadAttributes.ContentState(progress: 0, status: "Preparing")
    ModuleDownloadAttributes.ContentState(
        progress: 0.42, status: "Downloading",
        downloadedBytes: 4_400_000, totalBytes: 10_500_000
    )
    ModuleDownloadAttributes.ContentState(
        progress: 1.0, status: "Done",
        downloadedBytes: 10_500_000, totalBytes: 10_500_000
    )
    ModuleDownloadAttributes.ContentState(
        progress: 0.31, status: "Failed",
        downloadedBytes: 3_200_000, totalBytes: 10_500_000
    )
}
