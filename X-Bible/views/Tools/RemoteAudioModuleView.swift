//
//   ModuleRowView.swift
//   X-Bible
//
//   Created by Zoe Brooklyn on 6/10/26.
//

import SwiftUI
import XbibleEngine

struct RemoteAudioModuleView: View {
    let module: RemoteAudioModuleInfo
    let onDownloadTrigger: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Optional Album Artwork Thumbnail Layer
            if let artworkUrlString = module.artworkFile?.url, let url = URL(string: artworkUrlString) {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderBackground
                }
                .frame(width: 150, height: 160)
                .cornerRadius(8)
                .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(groupedBackgroundColor)
                    .frame(width: 150, height: 160)
                    .overlay(Image(systemName: "waveform").foregroundColor(.secondary))
            }
            
            // Text Meta Layout Section
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(module.displayTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(module.contributor ?? "Unknown Contributor")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(module.language)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(secondaryGroupedBackgroundColor))
                }
                
                Spacer()
                
                switch module.status {
                case .idle:
                    Button(action: onDownloadTrigger) {
                        Text("Get")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().stroke(Color.accentColor, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    
                case .downloading(let progress):
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(progress))
                            .stroke(
                                Color.accentColor,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 28, height: 28)
                    .frame(width: 44, height: 44)
                    
                case .installed:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(surfaceBackgroundColor))
        .frame(width: 180)
        // ─── SAFE INTERACTION ACTION SHEET PLATFORM RESOLUTION ───
        #if os(iOS)
        .contextMenu {
            contextMenuButtons
        } preview: {
            ModuleExpandedDetailPreview(module: module)
        }
        #else
        .contextMenu {
            contextMenuButtons
        }
        #endif
    }
    
    // --- COMPONENT SUB-VIEWS & DESIGN SYSTEM PROPERTIES ---
    
    @ViewBuilder
    private var contextMenuButtons: some View {
        Button {
            if case .idle = module.status { onDownloadTrigger() }
        } label: {
            Label(
                module.status == .installed ? "Downloaded Offline" : "Download Module",
                systemImage: module.status == .installed ? "checkmark.circle" : "arrow.down.circle"
            )
        }
        
        Button(action: {}) {
            Label("Share Module Link", systemImage: "square.and.arrow.up")
        }
    }
    
    @ViewBuilder
    private var placeholderBackground: some View {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
            .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
        #else
        Color.secondary
            .overlay(Image(systemName: "music.note"))
        #endif
    }
    
    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemGroupedBackground)
        #endif
    }
    
    private var secondaryGroupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
    private var surfaceBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor).opacity(0.5)
        #else
        return Color(.systemBackground)
        #endif
    }
}

// ─── COMPONENT: EXPANDED PREVIEW LAYOUT ───

struct ModuleExpandedDetailPreview: View {
    let module: RemoteAudioModuleInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                if let artworkUrlString = module.artworkFile?.url, let url = URL(string: artworkUrlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        #if os(macOS)
                        Color(NSColor.windowBackgroundColor)
                        #else
                        Color(.systemGroupedBackground)
                        #endif
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .clipped()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(module.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(module.contributor ?? "Unknown Contributor")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(module.language)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
            }
            
            if let description = module.description {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("About This Module")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(description)
                        .font(.footnote)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Features")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                HStack {
                    ForEach(module.features.features, id: \.self) { feature in
                        Text(feature.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                featureCapsuleBackground
                            )
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
    
    private var featureCapsuleBackground: some View {
        #if os(macOS)
        return Capsule().fill(Color(NSColor.controlBackgroundColor))
        #else
        return Capsule().fill(Color(.secondarySystemBackground))
        #endif
    }
}
