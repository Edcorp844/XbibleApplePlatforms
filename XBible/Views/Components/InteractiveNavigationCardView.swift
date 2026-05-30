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
                        Text(currentActiveTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(currentActiveSubtitle)
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
                .background(Color.white.opacity(0.06))
            }
            .buttonStyle(.plain)
            
            // --- EXPANDABLE NAVIGATION TREE SECTION ---
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    if let rootNode = viewModel.navigationTreeRoot {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(rootNode.children, id: \.id) { section in
                                    ForEach(section.children, id: \.id) { chapter in
                                        
                                        // Extracted Sub-view clears type-checking bottlenecks instantly
                                        ChapterRowView(
                                            chapter: chapter,
                                            rootNode: rootNode,
                                            isSelected: viewModel.selectedNodeId == chapter.id,
                                            onSelect: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    viewModel.selectedNodeId = chapter.id
                                                    isExpanded = false
                                                }
                                            }
                                        )
                                        
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .frame(maxHeight: 240)
                    } else {
                        Text("No Chapters Found")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .padding()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 40)
    }
    
    // MARK: - Dynamic State Helpers
    private var currentActiveTitle: String { "Power of Tongues" }
    private var currentActiveSubtitle: String { "Chapter 5 of 6" }
}

// MARK: - EXTRACTED ROW SUB-VIEW
struct ChapterRowView: View {
    let chapter: AudioNode
    let rootNode: AudioNode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                if isSelected {
                    Text("•••••")
                        .font(.caption)
                        .foregroundColor(.white)
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
                
                Text(durationString)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isSelected ? Color.white.opacity(0.04) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    // Isolate calculation logic away from view bodies
    private var chapterIndex: Int {
        let allChapters = rootNode.children.flatMap { $0.children }
        if let idx = allChapters.firstIndex(where: { $0.id == chapter.id }) {
            return idx + 1
        }
        return 1
    }
    
    private var durationString: String {
        // Safely unwrap optionals with a fallback of 0
        let start = chapter.startMs ?? 0
        let end = chapter.endMs ?? 0
        
        let diffSeconds = max(0, (end - start) / 1000)
        if diffSeconds == 0 { return "10m" } // Keeps your default fallback intact
        return "\(diffSeconds / 60)m"
    }
}
