//  InteractiveNavigationCardView.swift
//  XBible
//
import SwiftUI
import XbibleEngine

struct InteractiveNavigationCardView: View {
    @ObservedObject var viewModel: AudioBibleViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // --- HEADER DROPDOWN BUTTON ---
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentActiveTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(viewModel.currentActiveSubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            
            // --- EXPANDABLE NAVIGATION TREE SECTION ---
            if isExpanded {
                VStack(spacing: 0) {
                    let chapters = viewModel.cachedChaptersList
                    
                    if !chapters.isEmpty {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(chapters, id: \.stableId) { chapter in
                                    ChapterRowView(
                                        chapter: chapter,
                                        viewModel: viewModel,
                                        chapterIndex: viewModel.getChapterIndex(for: chapter.id),
                                        isSelected: viewModel.selectedNodeId == chapter.id,
                                        currentPlaybackMs: viewModel.playbackState?.currentTimeMs ?? 0, // 🌟 Feeds current clock digit downstream
                                        onSelect: {
                                            viewModel.seekToChapter(id: chapter.id)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                viewModel.selectedNodeId = chapter.id
                                                isExpanded = false
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                    } else {
                        HStack {
                            Spacer()
                            Text("Loading Navigation Catalog...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                                .padding()
                            Spacer()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    

    
}

// MARK: - LIGHTWEIGHT EXTRACTED ROW VIEW
struct ChapterRowView: View {
    let chapter: AudioNode
    let viewModel: AudioBibleViewModel
    let chapterIndex: Int
    let isSelected: Bool
    let currentPlaybackMs: Int64
    let onSelect: () -> Void
    
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                if isSelected {
                    AudioWaveIndicator(currentVolume: viewModel.liveAudioVolume)
                } else {
                    Text("\(chapterIndex)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, alignment: .leading)
                }
                
                Text(chapter.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                
                Spacer()
                
                // 🌟 Dynamic duration label swapping based on row context selection
                Text(durationString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isSelected ? Color.white.opacity(0.04) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private var durationString: String {
        let start = chapter.startMs ?? 0
        let end = chapter.endMs ?? 0
        
        if isSelected {
            // 🌟 Active Mode: Compute exact countdown time remaining
            let remainingMs = max(0, end - currentPlaybackMs)
            let remainingSeconds = remainingMs / 1000
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            
            // Returns standard media string format like: "- 2:14"
            return String(format: "- %d:%02d", minutes, seconds)
        } else {
            // Standard Inactive Row Layout
            let diffSeconds = max(0, (end - start) / 1000)
            if diffSeconds == 0 { return "10m" }
            return "\(diffSeconds / 60)m"
        }
    }
}
