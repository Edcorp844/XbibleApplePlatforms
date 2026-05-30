//  AudioBibleView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/29/26.
//

import SwiftUI
import XbibleEngine

struct AudioBibleView: View {
    @StateObject private var viewModel = AudioBibleViewModel()
    @State private var showLibrarySheet = false
    
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
            .overlay(
                Image(systemName: "book.closed.fill")
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
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .overlay(
                        Color.black
                            .opacity(0.45) // Dark overlay to match the deep tone of the screenshot
                            .ignoresSafeArea()
                    )
                    .animation(.easeInOut(duration: 0.6), value: viewModel.backgroundGradientColors)
                    
                    // --- 2. ASYMMETRICAL TWO-COLUMN DESKTOP SCREEN LAYOUT ---
                    HStack(spacing: 48) {
                        
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
                            Text(viewModel.selectedModule?.metadata?.language ?? "") // Placeholder timestamp matching design screenshot
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
                                
                                // Menu Context Button Dot
                                Button(action: { showLibrarySheet = true }) {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 20)
                            
                            // Scrubbing Timeline Slider Block
                            VStack(spacing: 6) {
                                // Simplified track bar mirroring screenshot style
                                let duration = Double(viewModel.selectedModule?.metadata?.durationMs ?? 3600000)
                                let current = Double(viewModel.playbackState?.currentTimeMs ?? 2945000) // 49:05 matching photo context
                                
                                //Slider(value: .constant(current), in: 0...duration)
                                AnimatedCustomSlider(value: .constant(current), range: 0...duration)
                                    
                                    //.accentColor(.white.opacity(0.8))
                                    //.controlSize(.large)
                                    
                                
                                HStack {
                                    Text(formatTime(ms: Int64(current)))
                                    Spacer()
                                    Text("-" + formatTime(ms: Int64(duration - current)))
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.bottom, 24)
                            
                            // Media Control Transport Strip
                            HStack(spacing: 0) {
                                Button(action: {}) { Text("1 x").font(.footnote).bold() }
                                Spacer()
                                Button(action: {}) { Image(systemName: "gobackward.15").font(.title).bold() }
                                Spacer()
                                Button(action: { viewModel.togglePlayback() }) {
                                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.largeTitle).bold()
                                }
                                Spacer()
                                Button(action: {}) { Image(systemName: "goforward.30").font(.title).bold() }
                                Spacer()
                                Button(action: {}) { Image(systemName: "repeat").font(.title3) }
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            
                            Spacer()
                        }
                        .frame(width: min(geometry.size.width * 0.38, 340))
                        
                        // ================= RIGHT SIDE PANEL: CONTENT STREAM =================
                        VStack(alignment: .leading, spacing: 20) {
//                            
//                            // Context Header Box Layout (e.g., Chapter details block)
//                            HStack {
//                                VStack(alignment: .leading, spacing: 4) {
//                                    Text("Power of Tongues")
//                                        .font(.system(size: 14, weight: .bold))
//                                        .foregroundStyle(.white)
//                                    Text("Chapter 5 of 6")
//                                        .font(.system(size: 12))
//                                        .foregroundStyle(.white.opacity(0.5))
//                                }
//                                Spacer()
//                                Image(systemName: "chevron.down")
//                                    .font(.caption)
//                                    .foregroundStyle(.white.opacity(0.5))
//                            }
//                            .padding(.horizontal, 16)
//                            .padding(.vertical, 12)
//                            .background(Color.white.opacity(0.08))
//                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//                            .padding(.top, 40)
                        
                        InteractiveNavigationCardView(viewModel:    AudioBibleViewModel())
                            
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
                                    
                                    // Primary Synchronized Active Verse Paragraph Blocks
                                    if let activeText = viewModel.playbackState?.activeText, !activeText.isEmpty {
                                        Text(activeText)
                                            .font(.system(size: 23, weight: .medium, design: .serif))
                                            .foregroundStyle(.white)
                                            .lineSpacing(8)
                                            .multilineTextAlignment(.leading)
                                    } else {
                                        Text("")
                                    }
                                }
                                .padding(.trailing, 10)
                                .padding(.bottom, 60)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 40)
                    
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
                        .padding(.trailing, 32)
                        .padding(.bottom, 32)
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
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
// --- CATALOG VIEW EXTENSION ---

