//  AudioBibleView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/29/26.
//

import SwiftUI
import XbibleEngine

struct AudioBibleView: View {
    @State private var showLibrarySheet = false
    @ObservedObject var viewModel: AudioBibleViewModel

    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
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
#if os(macOS)
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
                                }.disabled(viewModel.selectedModule == nil)
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
                                    Text(viewModel.formatTime(ms: Int64(current)))
                                    Spacer()
                                    Text("-" + viewModel.formatTime(ms: Int64(max(0, duration - current))))
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.bottom, 24)
                            
                            // Media Control Transport Strip
                            MediaControls(viewModel: viewModel)
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
                                            if let currentModule = viewModel.selectedModule {
                                               
                                                ScrollViewReader { proxy in
                                                    VStack(alignment: .leading, spacing: 28) { // Slightly wider spacing between paragraphs
                                                        // 1. Loop through your top-level chapters
                                                        ForEach(viewModel.cachedChaptersList, id: \.stableId) { chapter in
                                                            
                                                            // Subtle, clean Chapter Header breakdown
                                                            Text(chapter.title.uppercased())
                                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                                .foregroundColor(.white.opacity(0.2))
                                                                .padding(.top, 14)
                                                            
                                                            // 2. Loop directly over the child verse nodes inside this chapter
                                                            ForEach(chapter.childrenNodes ?? [], id: \.stableId) { sentenceNode in
                                                                
                                                                let activeTextString = viewModel.playbackState?.activeText ?? ""
                                                                let currentVerseText = sentenceNode.text ?? ""
                                                                
                                                                // Clean whitespace verification to match active spoken subtitles to raw verse text
                                                                let isActive = !activeTextString.isEmpty &&
                                                                    activeTextString.trimmingCharacters(in: .whitespacesAndNewlines) == currentVerseText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                                
                                                                Button(action: {
                                                                    // Tap navigation to the exact millisecond of this verse
                                                                    if let timestampMs = sentenceNode.startMs {
                                                                        viewModel.seekToTime(ms: timestampMs)
                                                                    }
                                                                }) {
                                                                    VStack(alignment: .leading, spacing: 6) {
                                                                        Text(sentenceNode.title) // e.g. "Verse 1"
                                                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                                                            .foregroundColor(isActive ? .orange.opacity(0.8) : .white.opacity(0.15))
                                                                        
                                                                        Text(currentVerseText) // Spoken Scripture content body
                                                                            .font(.system(size: 23, weight: .medium, design: .serif))
                                                                            .foregroundColor(isActive ? .white : .white.opacity(0.25))
                                                                            .lineSpacing(8)
                                                                            .multilineTextAlignment(.leading)
                                                                    }
                                                                    .scaleEffect(isActive ? 1.01 : 1.0)
                                                                    .blur(radius: isActive ? 0 : 0.3)
                                                                }
                                                                .buttonStyle(.plain)
                                                                .id(sentenceNode.id) // Bind target token for scrolling anchors
                                                            }
                                                        }
                                                    }
                                                    .onChange(of: viewModel.playbackState?.activeText) { newValue in
                                                        guard let incomingText = newValue else { return }
                                                        
                                                        // Scan the nested layout arrays to match the specific current sentence object
                                                        if let targetNode = viewModel.cachedChaptersList
                                                            .flatMap({ $0.childrenNodes ?? [] })
                                                            .first(where: { ($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == incomingText.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                                                            
                                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                                                proxy.scrollTo(targetNode.id, anchor: .center)
                                                            }
                                                        }
                                                    }
                                                }
                                            } else {
                                                
                                                VStack(alignment: .leading, spacing: 16) {
                                                    ForEach(viewModel.availableModules, id: \.fileName) { module in
                                                        Button(action: {
                                                            // Initialize module parsing pipeline on tap
                                                            viewModel.selectModule(module)
                                                        }) {
                                                            HStack(spacing: 14) {
                                                                Group {
                                                                    if let data = module.artwork.imageBytes() {
                                                                        #if os(macOS)
                                                                        if let compiledImage = NSImage(data: data) {
                                                                            Image(nsImage: compiledImage)
                                                                                .resizable()
                                                                                .scaledToFill()
                                                                                .frame(width: 50, height: 50)
                                                                                .cornerRadius(6)
                                                                                .clipped()
                                                                        } else {
                                                                            FallbackBadge(module: module)
                                                                        }
                                                                        #else // iOS 26 Target
                                                                        if let compiledImage = UIImage(data: data) {
                                                                            Image(uiImage: compiledImage)
                                                                                .resizable()
                                                                                .scaledToFill()
                                                                                .frame(width: 50, height: 50)
                                                                                .cornerRadius(6)
                                                                                .clipped()
                                                                        } else {
                                                                            FallbackBadge(module: module)
                                                                        }
                                                                        #endif
                                                                    } else {
                                                                        FallbackBadge(module: module)
                                                                    }
                                                                }
                                                                
                                                                VStack(alignment: .leading, spacing: 4) {
                                                                    HStack{
                                                                        VStack(alignment: .leading, spacing: 4){
                                                                            Text(module.metadata?.displayTitle ?? "")
                                                                                .font(.system(size: 14))
                                                                                .foregroundColor(.white)
                                                                                .lineLimit(1)
                                                                                .truncationMode(.tail)
                                                                            
                                                                            Text(module.metadata?.description ?? "")
                                                                                .font(.system(size: 12))
                                                                                .foregroundColor(.secondary)
                                                                                .lineLimit(1)
                                                                                .truncationMode(.tail)
                                                                            Text(module.metadata?.language ?? "")
                                                                                .font(.system(size: 12))
                                                                                .foregroundColor(.secondary)
                                                                                .lineLimit(1)
                                                                                .truncationMode(.tail)
                                                                        }
                                                                        
                                                                        Spacer()
                                                                        Button(action: {
                                                                            
                                                                        }) {
                                                                            Image(systemName: "ellipsis")
                                                                        }.buttonStyle(.plain)
                                                                    }
                                                                    
                                                                    Divider()
                                                                }
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                              

                                                            }
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
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
#if os(macOS)
                    .frame(width: geometry.size.width * 0.88, height: geometry.size.height * 0.84)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    #endif
                    // --- 3. FLOATING ACTION HUD (Bottom Right Corner Buttons) ---
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 16) {
                                Button(action: {}) { Image(systemName: "quote.bubble.fill").font(.title) }
                                Divider().background(Color.white.opacity(0.2)).frame(height: 16)
                                Button(action: { showLibrarySheet = true }) { Image(systemName: "list.bullet").font(.title) }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassEffect()
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
        #endif
        
        
        VStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.availableModules, id: \.fileName) { module in
                Button(action: {
                    // Initialize module parsing pipeline on tap
                    viewModel.selectModule(module)
                }) {
                    HStack(spacing: 14) {
                        Group {
                            if let data = module.artwork.imageBytes() {
#if os(macOS)
                                if let compiledImage = NSImage(data: data) {
                                    Image(nsImage: compiledImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(6)
                                        .clipped()
                                } else {
                                    FallbackBadge(module: module)
                                }
#else // iOS 26 Target
                                if let compiledImage = UIImage(data: data) {
                                    Image(uiImage: compiledImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(6)
                                        .clipped()
                                } else {
                                    FallbackBadge(module: module)
                                }
#endif
                            } else {
                                FallbackBadge(module: module)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack{
                                VStack(alignment: .leading, spacing: 4){
                                    Text(module.metadata?.displayTitle ?? "")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    Text(module.metadata?.description ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text(module.metadata?.language ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                
                                Spacer()
                                Button(action: {
                                    
                                }) {
                                    Image(systemName: "ellipsis")
                                }.buttonStyle(.plain)
                            }
                            
                            Divider()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        
                    }
                }
                .buttonStyle(.plain)
            }}
        
    }
}
