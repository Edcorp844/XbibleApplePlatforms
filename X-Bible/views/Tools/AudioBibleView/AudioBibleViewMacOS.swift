//
//  AudioBibleViewMacOS.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/17/26.
//

#if os(macOS)
import SwiftUI
import XbibleEngine

struct AudioBibleViewMacOS: View {
    @State private var selectedLanguageFilter: String? = nil
    @State private var selectedContributorFilter: String? = nil
    @State private var sortBySetting: SortOption = .title
    @State private var showLibrarySheet = false
    @State private var searchText = ""
    @ObservedObject var viewModel: AudioBibleViewModel
    
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case date = "Date"
        case contributor = "Contributor"
        case title = "Title"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    backgroundGradientView
                    
                    HStack(spacing: 54) {
                        leftSidePlayerPanel(width: min(geometry.size.width * 0.36, 320))
                        rightSideContentPanel
                    }
                    .frame(width: geometry.size.width * 0.88, height: geometry.size.height * 0.84)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    floatingActionHUD
                }
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .sheet(isPresented: $showLibrarySheet) {
                LibraryCatalogView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - 1. BACKGROUND COMPONENT
    @ViewBuilder
    private var backgroundGradientView: some View {
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
    }
    
    // MARK: - 2. LEFT PANEL: PLAYER CORE
    @ViewBuilder
    private func leftSidePlayerPanel(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            
            artworkView
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 16)
                .padding(.bottom, 28)
            
            Text(viewModel.selectedModule?.metadata?.language ?? "")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 2)
            
            playerMetadataHeader
                .padding(.bottom, 20)
            
            playerTimelineSlider
                .padding(.bottom, 24)
            
            MediaControls(viewModel: viewModel)
            Spacer()
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var playerMetadataHeader: some View {
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
            }
            .disabled(viewModel.selectedModule == nil)
            .buttonStyle(.plain)
            .help("Stop and clear playing module")
        }
    }
    
    @ViewBuilder
    private var playerTimelineSlider: some View {
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
    }
    
    // MARK: - 3. RIGHT PANEL: MAIN STREAM CONTENT
    @ViewBuilder
    private var rightSideContentPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 20) {
                    carouselPaginationDots
                    
                    if viewModel.selectedModule != nil {
                        verseTextScrollView
                    } else {
                        moduleCatalogScrollView
                    }
                }
                .padding(.top, 74)
                
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
    
    @ViewBuilder
    private var carouselPaginationDots: some View {
        HStack(spacing: 8) {
            Circle().fill(.white).frame(width: 7, height: 7)
            Circle().fill(.white).frame(width: 7, height: 7)
            Circle().fill(.white.opacity(0.25)).frame(width: 7, height: 7)
        }
        .padding(.leading, 4)
    }
    
    @ViewBuilder
    private var verseTextScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(viewModel.cachedChaptersList, id: \.stableId) { chapter in
                            Text(chapter.title.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.2))
                                .padding(.top, 14)
                            
                            // Updated to read directly from the non-optional [AudioNode] collection
                            ForEach(chapter.children, id: \.stableId) { sentenceNode in
                                verseRowButton(for: sentenceNode)
                            }
                        }
                    }
                    .onChange(of: viewModel.activeText) {
                        let incomingText = viewModel.activeText
                        if let targetNode = findMatchingNode(for: incomingText) {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                proxy.scrollTo(targetNode.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.trailing, 10)
            .padding(.bottom, 80)
        }
    }
    
    @ViewBuilder
    private func verseRowButton(for sentenceNode: AudioNode) -> some View {
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
    
    @ViewBuilder
    private var moduleCatalogScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(processedModules, id: \.fileName) { module in
                    moduleRowButton(for: module)
                }
            }
            .padding(.horizontal, 16)
            .padding(.trailing, 10)
            .padding(.bottom, 80)
        }
    }
    
    @ViewBuilder
    private func moduleRowButton(for module: AudioModuleInfo) -> some View {
        Button(action: {
            viewModel.selectModule(module)
        }) {
            HStack(spacing: 14) {
                Group {
                    if let data = module.artwork.imageBytes(),
                       let compiledImage = NSImage(data: data) {
                        Image(nsImage: compiledImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(6)
                            .clipped()
                    } else {
                        FallbackBadge(module: module)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(module.metadata?.displayTitle ?? "Unknown Title")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text(module.metadata?.description ?? "No description available")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text(module.metadata?.language ?? "Unknown Language")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button(role: .destructive) {
                                // Context delete action string
                            } label: {
                                Label("Remove Module", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 32, height: 32)
                    }
                    Divider()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 4. FLOATING HUD
    @ViewBuilder
    private var floatingActionHUD: some View {
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
    
    @ViewBuilder
    private var artworkView: some View {
        if let nsImage = viewModel.decodedArtwork {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackArtworkBackground
        }
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
    
    // MARK: - 5. DETACHED SCROLL SYNC LOGIC ENGINE
    private func findMatchingNode(for incomingText: String) -> AudioNode? {
        let cleanedIncoming = incomingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedIncoming.isEmpty { return nil }
        
        for chapter in viewModel.cachedChaptersList {
            for node in chapter.children {
                let nodeText = (node.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if nodeText == cleanedIncoming {
                    return node
                }
            }
        }
        return nil
    }
    
    // MARK: - 6. FILTER & SORT LOGIC CHANNELS
    private var processedModules: [AudioModuleInfo] {
        var modules = viewModel.availableModules
        
        if !searchText.isEmpty {
            modules = modules.filter { module in
                let title = module.metadata?.displayTitle ?? ""
                let description = module.metadata?.description ?? ""
                let contributor = module.metadata?.contributor ?? ""
                
                return title.localizedCaseInsensitiveContains(searchText) ||
                description.localizedCaseInsensitiveContains(searchText) ||
                contributor.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let language = selectedLanguageFilter {
            modules = modules.filter { $0.metadata?.language == language }
        }
        if let contributor = selectedContributorFilter {
            modules = modules.filter { $0.metadata?.contributor == contributor }
        }
        
        switch sortBySetting {
        case .title:
            modules.sort { ($0.metadata?.displayTitle ?? "") < ($1.metadata?.displayTitle ?? "") }
        case .contributor:
            modules.sort { ($0.metadata?.contributor ?? "") < ($1.metadata?.contributor ?? "") }
        case .date:
            modules.sort { ($0.metadata?.version ?? 0) > ($1.metadata?.version ?? 0) }
        }
        
        return modules
    }
    
    private func sortIcon(for option: SortOption) -> String {
        switch option {
        case .title: return "textformat"
        case .contributor: return "person.crop.circle"
        case .date: return "calendar"
        }
    }
}
#endif
