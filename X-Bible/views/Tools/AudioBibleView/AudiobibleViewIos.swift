//
//  AudiobibleViewIos.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/17/26.
//

import SwiftUI
import XbibleEngine

#if os(iOS)
struct AudiobibleViewIos: View {
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
            ZStack {
                // Main Module List
                List {
                    ForEach(processedModules, id: \.fileName) { module in
                        moduleRow(module)
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Audio Bible")
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search audiobooks...")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        filterMenu
                        sortMenu
                    }
                }
                
                // Now Playing Overlay
                if viewModel.selectedModule != nil {
                    nowPlayingOverlay
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
            }
            // Animate the overlay sliding up/down
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedModule != nil)
        }
    }
    
    // MARK: - Now Playing Overlay (Lyrics + Controls)
    
    private var nowPlayingOverlay: some View {
        ZStack(alignment: .top) {
            // Dynamic Background Gradient
            LinearGradient(
                colors: viewModel.backgroundGradientColors,
                startPoint: .bottomTrailing,
                endPoint: .topLeading
            )
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.4).ignoresSafeArea())
            
            VStack(spacing: 0) {
                // Top Bar (Minimize / Stop)
                HStack {
                    Button(action: { withAnimation { viewModel.stopPlayback() } }) {
                        Image(systemName: "chevron.down")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Now Playing")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    // Balance layout
                    Image(systemName: "chevron.down").opacity(0)
                }
                .padding()
                
                // Scrollable Lyrics
                lyricsScrollView
                
                // Bottom Player Controls
                playerControls
                    .padding()
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
        }
    }
    
    // MARK: - Lyrics Scroll View
    
    private var lyricsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.cachedChaptersList, id: \.stableId) { chapter in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(chapter.title.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.top, 14)
                            
                            ForEach(chapter.children, id: \.stableId) { sentenceNode in
                                verseRowButton(for: sentenceNode)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .onChange(of: viewModel.activeText) { _, incomingText in
                guard let targetNode = findMatchingNode(for: incomingText) else { return }
                
                // Delay the scroll slightly so the VStack layout is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        proxy.scrollTo(targetNode.stableId, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func verseRowButton(for sentenceNode: AudioNode) -> some View {
        let activeTextString = viewModel.activeText
        let currentVerseText = sentenceNode.text ?? ""
        let isActive = !activeTextString.isEmpty &&
        activeTextString.trimmingCharacters(in: .whitespacesAndNewlines) == currentVerseText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Button(action: {
            if let timestampMs = sentenceNode.startMs {
                viewModel.seekToTime(ms: timestampMs)
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(sentenceNode.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? .orange.opacity(0.8) : .white.opacity(0.2))
                
                Text(currentVerseText)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundColor(isActive ? .white : .white.opacity(0.3))
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
            }
            .scaleEffect(isActive ? 1.01 : 1.0)
            .blur(radius: isActive ? 0 : 0.3)
        }
        .buttonStyle(.plain)
        .id(sentenceNode.stableId)
    }
    
    // MARK: - Player Controls
    
    private var playerControls: some View {
        VStack(spacing: 12) {
            // Metadata
            HStack {
                if let data = viewModel.selectedModule?.artwork.imageBytes(), let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "headphones").foregroundColor(.white))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedModule?.metadata?.displayTitle ?? "Unknown Title")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.selectedModule?.metadata?.contributor ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }
            
            // Slider & Time
            let duration = Double(viewModel.selectedModule?.metadata?.durationMs ?? 3600000)
            let current = Double(viewModel.currentTimeMs)
            
            VStack(spacing: 4) {
                AnimatedCustomSlider(
                    value: Binding<Double>(
                        get: { current },
                        set: { newValue in viewModel.seekToTime(ms: Int64(newValue)) }
                    ),
                    range: 0...duration,
                    isActive: viewModel.isPlaying
                )
                
                HStack {
                    Text(viewModel.formatTime(ms: Int64(current)))
                    Spacer()
                    Text("-" + viewModel.formatTime(ms: Int64(max(0, duration - current))))
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            }
            
            // Playback Buttons
            MediaControls(viewModel: viewModel, inMiniPlayer: false)
        }
    }
    
    // MARK: - Module List Row
    
    private func moduleRow(_ module: AudioModuleInfo) -> some View {
        HStack(spacing: 14) {
            // Main Tappable Area
            HStack(spacing: 14) {
                Group {
                    if let data = module.artwork.imageBytes(), let compiledImage = UIImage(data: data) {
                        Image(uiImage: compiledImage)
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
                    Text(module.metadata?.displayTitle ?? "Unknown Title")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(module.metadata?.description ?? "No description available")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(module.metadata?.language ?? "Unknown Language")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectModule(module)
            }
            
            Spacer()
            
            // Options Menu
            Menu {
                Button(role: .destructive) {
                    // Handle context deletion
                } label: {
                    Label("Remove Module", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, 4)
    }
    
    // MARK: - Menus & Helpers
    
    private var filterMenu: some View {
        Menu {
            Menu("Language") {
                Button("All Languages", action: { selectedLanguageFilter = nil })
                ForEach(Array(Set(viewModel.availableModules.compactMap { $0.metadata?.language })), id: \.self) { lang in
                    Button(lang, action: { selectedLanguageFilter = lang })
                }
            }
            
            Menu("Contributor") {
                Button("All Contributors", action: { selectedContributorFilter = nil })
                ForEach(Array(Set(viewModel.availableModules.compactMap { $0.metadata?.contributor })), id: \.self) { contributor in
                    Button(contributor, action: { selectedContributorFilter = contributor })
                }
            }
            
            if selectedLanguageFilter != nil || selectedContributorFilter != nil {
                Divider()
                Button(role: .destructive, action: {
                    selectedLanguageFilter = nil
                    selectedContributorFilter = nil
                }) {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: (selectedLanguageFilter != nil || selectedContributorFilter != nil) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
    
    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortBySetting) {
                ForEach(SortOption.allCases) { option in
                    Label(option.rawValue, systemImage: sortIcon(for: option))
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
    
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
