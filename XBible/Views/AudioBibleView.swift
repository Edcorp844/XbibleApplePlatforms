//  AudioBibleView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/29/26.
//

import SwiftUI
import XbibleEngine

struct AudioBibleView: View {
    @State private var showLibrarySheet = false
    @StateObject private var viewModel: AudioBibleViewModel

    init(engine: AudioEngine) {
        _viewModel = StateObject(wrappedValue: AudioBibleViewModel(engine: engine))
    }
    
    // Cross-platform artwork mapping resolver
    @ViewBuilder
    private var artworkView: some View {
        #if os(macOS)
        if let nsImage = viewModel.decodedArtwork {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackArtworkBackground
        }
        #else
        if let uiImage = viewModel.decodedArtwork {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackArtworkBackground
        }
        #endif
    }
    
    private var fallbackArtworkBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(
                colors: [.purple.opacity(0.3), .indigo.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .aspectRatio(contentMode: .fit)
            .overlay(
                Image(systemName: "headphones")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.6))
            )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // --- 1. DYNAMIC MATTE BACKGROUND GRADIENT ---
                    LinearGradient(
                        colors: viewModel.backgroundGradientColors,
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                    .ignoresSafeArea()
                    .overlay(
                        Color.black
                            .opacity(0.45)
                            .ignoresSafeArea()
                    )
                    .animation(.easeInOut(duration: 0.6), value: viewModel.backgroundGradientColors)
                    
                    // --- 2. ASYMMETRICAL TWO-COLUMN DESKTOP SCREEN LAYOUT ---
                    HStack(spacing: 54) {
                        
                        // ================= LEFT SIDE PANEL: PLAYER CORE =================
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                            
                            // High-fidelity Album Art Canvas
                            artworkView
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 16)
                                .padding(.bottom, 28)
                            
                            // Date metadata text tag if applicable
                            Text(viewModel.selectedModule?.metadata?.language ?? "")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.bottom, 2)
                            
                            // Track / Module Metadata Block
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.selectedModule?.metadata?.displayTitle ?? "XBible Audio Module")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    
                                    Text(viewModel.selectedModule?.metadata?.contributor ?? "XBible Media")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                    
                                Spacer()
                                    
                                // 🌟 FIX: Pointed directly to viewModel lifecycle and fixed the forward skip bug
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        viewModel.stopPlayback()
                                    }
                                }) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .help("Stop and clear playing module")
                            }
                            .padding(.bottom, 20)
                            
                            // Scrubbing Timeline Slider Block
                            VStack(spacing: 6) {
                                let duration = Double(viewModel.selectedModule?.metadata?.durationMs ?? 3600000)
                                let current = Double(viewModel.playbackState?.currentTimeMs ?? 0)
                                let isAudioPlaying = viewModel.playbackState?.isPlaying ?? false
                                
                                AnimatedCustomSlider(
                                    value: Binding<Double>(
                                        get: { current },
                                        set: { newValue in
                                            // 🌟 PIPELINE SEEK OUTBOUND: Routed cleanly via viewModel wrapper execution
                                            viewModel.seekToTime(ms: Int64(newValue))
                                        }
                                    ),
                                    range: 0...duration,
                                    isActive: isAudioPlaying
                                )
                                    
                                HStack {
                                    Text(formatTime(ms: Int64(current)))
                                    Spacer()
                                    Text("-" + formatTime(ms: Int64(max(0, duration - current))))
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.bottom, 24)
                            
                            // Media Control Transport Strip
                            HStack(spacing: 0) {
                                Button(action: {}) { Text("1 x").font(.footnote).bold() }
                                
                                Spacer()
                                
                                // 🌟 BACKWARD SKIP 15S: Redirected to viewModel wrapper pipeline directly
                                Button(action: {
                                    viewModel.skipBackward()
                                }) {
                                    Image(systemName: "gobackward.15").font(.title2).bold()
                                }
                                
                                Spacer()
                                    
                                Button(action: {
                                    viewModel.togglePlayback()
                                }) {
                                    Image(systemName: (viewModel.playbackState?.isPlaying ?? false) ? "pause.fill" : "play.fill")
                                        .font(.title).bold()
                                }
                                    
                                Spacer()
                                
                                // 🌟 FORWARD SKIP 30S: Redirected to viewModel wrapper pipeline directly
                                Button(action: {
                                    viewModel.skipForward()
                                }) {
                                    Image(systemName: "goforward.30").font(.title2).bold()
                                }
                                
                                Spacer()
                                
                                // 🌟 DYNAMIC REPEAT MODE CYCLE CONTROL: Updated properties syntax to match safe internal mappings
                                let currentRepeat = viewModel.playbackState?.repeatMode ?? .off
                                Button(action: {
                                    let nextMode: RepeatMode
                                    switch currentRepeat {
                                    case .off: nextMode = .one
                                    case .one: nextMode = .all
                                    case .all: nextMode = .off
                                    }
                                    viewModel.setRepeatMode(mode: nextMode)
                                }) {
                                    Image(systemName: currentRepeat == .one ? "repeat.1" : "repeat")
                                        .font(.title3)
                                        .foregroundStyle(currentRepeat == .off ? .white.opacity(0.4) : .cyan)
                                }
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            
                            Spacer()
                        }
                        .frame(width: min(geometry.size.width * 0.36, 320))
                        .frame(maxHeight: .infinity)
                        
                        // ================= RIGHT SIDE PANEL: CONTENT STREAM =================
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .topLeading) {
                                // 1. UNDERLAY LAYER: Scrollable Content & Pagination Indicators
                                VStack(alignment: .leading, spacing: 20) {
                                    
                                    // Layout Carousel Pagination Indicator Dots
                                    HStack(spacing: 8) {
                                        Circle().fill(.white).frame(width: 7, height: 7)
                                        Circle().fill(.white).frame(width: 7, height: 7)
                                        Circle().fill(.white.opacity(0.25)).frame(width: 7, height: 7)
                                    }
                                    .padding(.leading, 4)
                                    
                                    // Multi-Line Scrollable Structural Verse Engine Layout Container
                                    ScrollView(showsIndicators: false) {
                                        VStack(alignment: .leading, spacing: 24) {
                                            if let activeText = viewModel.playbackState?.activeText, !activeText.isEmpty {
                                                Text(activeText)
                                                    .font(.system(size: 23, weight: .medium, design: .serif))
                                                    .foregroundStyle(.white)
                                                    .lineSpacing(8)
                                                    .multilineTextAlignment(.leading)
                                            } else {
                                                Text("Select a module or chapter to begin reading.")
                                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                                    .foregroundStyle(.white.opacity(0.3))
                                            }
                                        }
                                        .padding(.trailing, 10)
                                        .padding(.bottom, 80)
                                    }
                                }
                                .padding(.top, 74)
                                
                                // 2. OVERLAY LAYER: Floating Interactive Card
                                InteractiveNavigationCardView(viewModel: viewModel)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                                    )
                                    .zIndex(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: geometry.size.width * 0.88, height: geometry.size.height * 0.84)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    // --- 3. FLOATING ACTION HUD (Bottom Right Corner Buttons) ---
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 16) {
                                Button(action: {}) { Image(systemName: "quote.bubble.fill").font(.subheadline) }
                                Divider().background(Color.white.opacity(0.2)).frame(height: 16)
                                Button(action: { showLibrarySheet = true }) { Image(systemName: "list.bullet").font(.subheadline) }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.3).background(.ultraThinMaterial))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                            .buttonStyle(.plain)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 40)
                        .padding(.bottom, 40)
                    }
                }
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .sheet(isPresented: $showLibrarySheet) {
                LibraryCatalogView(viewModel: viewModel)
            }
        }
    }
    
    private func formatTime(ms: Int64) -> String {
        let totalSeconds = max(0, ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
