//
//  ModuleDetailView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 10/31/26.
//


//
//  ModuleDetailView.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct ModuleDetailView: View {
    let module: RemoteAudioModuleInfo
    @ObservedObject var viewModel: AudioStoreViewModel

    private var liveModule: RemoteAudioModuleInfo {
        viewModel.availableModules.first(where: { $0.uniqueId == module.uniqueId }) ?? module
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 20) {
                    artwork
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.separator, lineWidth: 0.5))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(liveModule.displayTitle).font(.title2.bold())
                        if let c = liveModule.contributor {
                            Label(c, systemImage: "person.wave.2")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        statusBadge
                    }
                }

                metadataGrid

                if !liveModule.features.features.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features").font(.headline)
                        FlowLayout(spacing: 8) {
                            ForEach(liveModule.features.features, id: \.self) { f in
                                Text(f)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }

                if let d = liveModule.description, !d.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About").font(.headline)
                        Text(d).font(.body).textSelection(.enabled)
                    }
                }

                installControl
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle(liveModule.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var artwork: some View {
        if let bytes = liveModule.albumArtworkBytes, let img = platformImage(from: Data(bytes)) {
            img.resizable().aspectRatio(contentMode: .fill)
        } else if let bytes = liveModule.artworkBytes, let img = platformImage(from: Data(bytes)) {
            img.resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "waveform")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadataGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            row("Module ID", liveModule.uniqueId, mono: true)
            row("Version", "v\(liveModule.version)")
            row("Duration", formattedDuration(liveModule.durationMs))
            if !liveModule.sourceUrl.isEmpty {
                row("Source", liveModule.sourceUrl, mono: true)
            }
        }
    }

    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch liveModule.status {
        case .installed:
            Label("Installed", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
        case .downloading(let p):
            Label("\(Int(p * 100))%", systemImage: "arrow.down.circle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(.tint)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var installControl: some View {
        switch liveModule.status {
        case .installed:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.green)
        case .downloading(let p):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading").font(.headline)
                    Spacer()
                    Text("\(Int(p * 100))%").font(.callout.monospacedDigit())
                }
                ProgressView(value: p)
            }
        case .idle:
            Button {
                viewModel.installModule(id: liveModule.uniqueId)
            } label: {
                Label("Install", systemImage: "arrow.down.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func formattedDuration(_ ms: Int64) -> String {
        let s = ms / 1000
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%dh %02dm %02ds", h, m, sec)
            : String(format: "%dm %02ds", m, sec)
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #else
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #endif
    }
}