//
//  ModuleCard.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct ModuleCard: View {
    let module: RemoteAudioModuleInfo
    @ObservedObject var viewModel: AudioStoreViewModel

    private var liveModule: RemoteAudioModuleInfo {
        viewModel.availableModules.first(where: { $0.uniqueId == module.uniqueId }) ?? module
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Artwork (Top)
            ZStack(alignment: .topTrailing) {
                artwork
                    .aspectRatio(1, contentMode: .fit) // Perfect square
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.separator, lineWidth: 0.5)
                    )

                // Status badge overlay (top right corner of artwork)
                if case .downloading(let p) = liveModule.status {
                    Text("\(Int(p * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
            }

            // 2. Text Content (Bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(liveModule.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let contributor = liveModule.contributor {
                    Text(contributor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // 3. Install / Status Control
            HStack {
                statusPill
                Spacer()
                installControl
            }
            .padding(.top, 2)
        }
        // No heavy background or stroke around the whole tile, just the artwork
        .contentShape(Rectangle())
    }

    // MARK: - Artwork
    
    @ViewBuilder
    private var artwork: some View {
        if let urlString = liveModule.artworkFile?.url,
           let url = URL(string: urlString) {
            
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.secondary.opacity(0.1)
                        ProgressView().controlSize(.small)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderArtwork
                @unknown default:
                    placeholderArtwork
                }
            }
        } else if let bytes = liveModule.artworkBytes, let img = platformImage(from: Data(bytes)) {
            img.resizable().aspectRatio(contentMode: .fill)
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "waveform")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - UI Components

    @ViewBuilder
    private var statusPill: some View {
        switch liveModule.status {
        case .installed:
            Label("Installed", systemImage: "checkmark.seal.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.green)
        case .downloading:
            Label("Downloading", systemImage: "arrow.down.circle.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tint)
        case .idle:
            Label("Available", systemImage: "circle")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var installControl: some View {
        switch liveModule.status {
        case .idle:
            Button {
                viewModel.installModule(id: liveModule.uniqueId)
            } label: {
                Text("Get")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .help("Install")
            
        case .downloading(let p):
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: CGFloat(p))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: p)
            }
            .frame(width: 20, height: 20)
            
        case .installed:
            // Removed the checkmark icon completely.
            // You can leave this EmptyView or add text here if you want.
            EmptyView()
        }
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
