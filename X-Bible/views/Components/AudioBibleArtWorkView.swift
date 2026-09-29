//
//   AudioBibleArtWorkView.swift
//   X-Bible
//
//   Created by Zoe Brooklyn on 6/13/26.
//
import SwiftUI
import XbibleEngine

struct AudioBibleArtWorkView: View {
    @ObservedObject var viewModel: AudioBibleViewModel
    @State private var showScriptures: Bool = false
    
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
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
                    if showScriptures {
                        // High-fidelity Album Art Canvas
                        artworkView
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 16)
                            .padding(.bottom, 48)
                            .padding(.horizontal, 48)
                        
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
                            let current = Double(viewModel.currentTimeMs)
                            let isAudioPlaying = viewModel.isPlaying
                            
                            AnimatedCustomSlider(
                                value: Binding<Double>(
                                    get: { current },
                                    set: { newValue in
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
                        MediaControls(viewModel: viewModel, inMiniPlayer: false)
                        Spacer()
                    } else {
                        ZStack(alignment: .topLeading, ) {
                            // 1. UNDERLAY LAYER: Scrollable Content & Pagination Indicators
                            Spacer(minLength: 50)
                            VStack(alignment: .leading, spacing: 20) {
                                Spacer(minLength: 50)
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
                                        scriptureListView
                                    }
                                }
                            }
                            
                            InteractiveNavigationCardView(viewModel: viewModel)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                                )
                                .zIndex(1)
                        }.padding(.top, 24)
                    }
                        
                    HStack {
                        Button(action: {
                            showScriptures.toggle()
                        }){
                            Image(systemName: "ellipsis")
                        }
                    }
                    .padding()
                    Spacer()
                }
            }.padding(.horizontal, 24)
        }
        //.frame(maxHeight: .infinity)
    }
    
    // --- EXTRACTED CONTAINER TO DECREASE DECLARATIVE NESTING DEPTH ---
    @ViewBuilder
    private var scriptureListView: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 28) {
                ForEach(viewModel.cachedChaptersList, id: \.stableId) { chapter in
                    
                    Text(chapter.title.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.top, 14)
                    
                    ForEach(chapter.children, id: \.stableId) { sentenceNode in
                        let activeTextString = viewModel.activeText
                        let currentVerseText = sentenceNode.text ?? ""
                        let isActive = !activeTextString.isEmpty &&
                        activeTextString.trimmingCharacters(in: .whitespacesAndNewlines) == currentVerseText.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        Button(action: {
                            if let timestampMs = sentenceNode.startMs {
                                viewModel.seekToTime(ms: timestampMs)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(sentenceNode.title)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(isActive ? .orange.opacity(0.8) : .white.opacity(0.15))
                                
                                Text(currentVerseText)
                                    .font(.system(size: 23, weight: .medium, design: .serif))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.25))
                                    .lineSpacing(8)
                                    .multilineTextAlignment(.leading)
                            }
                            .scaleEffect(isActive ? 1.01 : 1.0)
                            .blur(radius: isActive ? 0 : 0.3)
                        }
                        .buttonStyle(.plain)
                        .id(sentenceNode.id)
                    }
                }
            }
            .onChange(of: viewModel.activeText) {
                // 🚀 FIXED: Direct variable load without conditional unwrap
                let incomingText = viewModel.activeText
                
                if let targetNode = findMatchingNode(for: incomingText) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        proxy.scrollTo(targetNode.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // --- TYPE-CHECKER ISOLATION HELPER ---
    private func findMatchingNode(for incomingText: String) -> AudioNode? {
        let cleanedIncoming = incomingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedIncoming.isEmpty { return nil }
        
        for chapter in viewModel.cachedChaptersList {
            // 🚀 FIXED: Clean sequential iteration safely over verified non-optional collections
            for node in chapter.children {
                let nodeText = (node.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if nodeText == cleanedIncoming {
                    return node
                }
            }
        }
        return nil
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
}
