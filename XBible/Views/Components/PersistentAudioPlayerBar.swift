//
//  PersistentAudioPlayerBar.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/30/26.
//

import SwiftUI
import XbibleEngine

struct PersistentAudioPlayerBar: View {
    @ObservedObject var viewModel: AudioBibleViewModel
    @State private var localScrubProgress: Double? = nil
    
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    

    var body: some View {
        if viewModel.selectedModule == nil {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    
                    // ================= 1. LEFT: MEDIA TRANSPORT ROW =================
                    MediaControls(viewModel: viewModel)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // ================= 2. CENTER: COMPACT TRACK METADATA =================
                    HStack(spacing: 8) {
                        if let artwork = viewModel.decodedArtwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        } else {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, height: 40)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(viewModel.selectedModule?.metadata?.displayTitle ?? "Audio Chapter")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            
                            Text(viewModel.currentActiveTitle)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            
                            let duration = Double(viewModel.selectedModule?.metadata?.durationMs ?? 3600000)
                            let current = Double(viewModel.playbackState?.currentTimeMs ?? 0)
                            let isAudioPlaying = viewModel.playbackState?.isPlaying ?? false
                            
//                            HStack {
//                                Text(viewModel.formatTime(ms: Int64(current))).font(.system(size: 8))
//                                Spacer()
//                                Text("-" + viewModel.formatTime(ms: Int64(max(0, duration - current)))).font(.system(size: 8))
//                            }
                            
                            AnimatedCustomSlider(
                                value: Binding<Double>(
                                    get: { current },
                                    set: { newValue in
                                        viewModel.seekToTime(ms: Int64(newValue))
                                    }
                                ),
                                range: 0...duration,
                                idleHeight: 2,
                                interactingHeight: 4,
                                isActive: isAudioPlaying,
                            )
                        }
                    }
                    .frame(minWidth: 100, maxWidth: 320, alignment: .leading)
                    .layoutPriority(1)
                    
                    Spacer(minLength: 8)
                    
                    // ================= 3. RIGHT: MINIFIED UTILITY ACTIONS =================
                    HStack(spacing: 12) {
                        Button(action: {
                            
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .bold()
                        }
                        .disabled(viewModel.selectedModule == nil)
                        .buttonStyle(.plain)
                        
                        Button(action: {
                           
                        }) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.title2)
                                .bold()
                        }
                        .disabled(viewModel.selectedModule == nil)
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(8)
            .frame(maxWidth: 540)
            .glassEffect()
        }
    }
}
