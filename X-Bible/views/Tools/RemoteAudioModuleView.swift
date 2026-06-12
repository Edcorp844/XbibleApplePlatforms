//
//  ModuleRowView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/10/26.
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
                    Color(.systemGroupedBackground)
                        .overlay(Image(systemName: "music.note"))
                }
                .frame(width: 150, height: 160)
                .cornerRadius(8)
                .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGroupedBackground))
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
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
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
                        // Background Track Ring
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                        
                        // Active Progress Ring
                        Circle()
                            .trim(from: 0.0, to: CGFloat(progress))
                            .stroke(
                                Color.accentColor,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90)) // Starts the path at 12 o'clock
                            .animation(.linear(duration: 0.1), value: progress) // Smooths out the incremental jumps
                        
                        // Centered Telemetry String
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 28, height: 28) // Perfectly contained ring bounds
                    .frame(width: 44, height: 44) // Outer interactive hitbox frame to match your other rows
                    
                case .installed:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .frame(width: 180)
        // ─── NATIVE iOS DETAILED LONG-PRESS ACTION POPOVER ───
        .contextMenu {
            // Context Action Options
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
        } preview: {
            // This closure creates the exact preview canvas sheet that slides out upon long pressing
            ModuleExpandedDetailPreview(module: module)
        }
    }
}

// ─── COMPONENT: EXPENDED PREVIEW LAYOUT ───

struct ModuleExpandedDetailPreview: View {
    let module: RemoteAudioModuleInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                if let artworkUrlString = module.artworkFile?.url, let url = URL(string: artworkUrlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemGroupedBackground)
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
            
            // Rendering features list array context tokens
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
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
}


