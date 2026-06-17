//
//  ContentView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/12/26.
//

import SwiftUI
import SwiftData
import XbibleEngine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject var wrapper: SwordEngineWrapper
    
    private let coreAudioEngine: AudioEngine
    @StateObject private var audioViewModel: AudioBibleViewModel
    @State private var expandMiniPlayer: Bool = false
    
    init() {
        let engine = AudioEngine()
        self.coreAudioEngine = engine
        self._audioViewModel = StateObject(wrappedValue: AudioBibleViewModel(engine: engine))
    }
    
    var body: some View {
#if os(macOS)
        // ─────────────────────────────────────────────────────────────────
        //  macOS HIERARCHICAL MATRIX (ZStack Wrapper Root Layout)
        // ─────────────────────────────────────────────────────────────────
        ZStack(alignment: .bottom) {
            macOSTabView
            
            if audioViewModel.selectedModule != nil && wrapper.selectedSidebarItem != .audioBible {
                PersistentAudioPlayerBar(viewModel: audioViewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioViewModel.selectedModule != nil)
        .onAppear { refreshEngineIfNeeded() }
        .onChange(of: wrapper.isReady) { _, isReady in if isReady { wrapper.refreshReadingEngine() } }
        
#else
        // ─────────────────────────────────────────────────────────────────
        //  iOS MOBILE ARCHITECTURE (ZStack Content Isolation)
        // ─────────────────────────────────────────────────────────────────
        ZStack(alignment: .bottom) {
            TabView(selection: $wrapper.selectedSidebarItem) {
                Tab(value: SidebarItem.all, role: .search) {
                    DetailView(selection: .all, viewModel: audioViewModel)
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                
                Tab(value: SidebarItem.study) {
                    DetailView(selection: .study, viewModel: audioViewModel)
                } label: {
                    Label(SidebarItem.study.title, systemImage: SidebarItem.study.icon)
                }
                
                Tab(value: SidebarItem.store) {
                    DetailView(selection: .store, viewModel: audioViewModel)
                } label: {
                    Label(SidebarItem.store.title, systemImage: SidebarItem.store.icon)
                }
                
                if sizeClass == .regular {
                    TabSection("Tools") {
                        Tab(value: SidebarItem.audioBible) {
                            AudioBibleView(viewModel: audioViewModel)
                        } label: {
                            Label(SidebarItem.audioBible.title, systemImage: SidebarItem.audioBible.icon)
                        }
                        Tab(value: SidebarItem.bibleTimeline) {
                            DetailView(selection: .bibleTimeline, viewModel: audioViewModel)
                        } label: {
                            Label(SidebarItem.bibleTimeline.title, systemImage: SidebarItem.bibleTimeline.icon)
                        }
                    }
                } else {
                    Tab(value: SidebarItem.tools) {
                        DetailView(selection: .tools, viewModel: audioViewModel)
                    } label: {
                        Label(SidebarItem.tools.title, systemImage: SidebarItem.tools.icon)
                    }
                }
                
                if sizeClass == .regular {
                    TabSection("Library") {
                        ForEach(getAvailableCategories(), id: \.self) { item in
                            Tab(item.title, systemImage: item.icon, value: item) {
                                DetailView(selection: item, viewModel: audioViewModel)
                            }
                        }
                    }
                } else {
                    Tab(value: SidebarItem.all) {
                        DetailView(selection: .all, viewModel: audioViewModel)
                    } label: {
                        Label(SidebarItem.all.title, systemImage: SidebarItem.all.icon)
                    }
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewStyle(.sidebarAdaptable)
            .defaultAdaptableTabBarPlacement(.sidebar)
            
            // Floating Overlay Mini-Player for Compact iPhones (Prevents TabView constraints crushing internal Toolbars)
            if audioViewModel.selectedModule != nil && sizeClass == .compact {
                AudioMiniPayer(
                    displayTitle: audioViewModel.selectedModule?.metadata?.displayTitle ?? "Audio Chapter",
                    activeLyricTitle: audioViewModel.currentActiveTitle,
                    isPlaying: audioViewModel.isPlaying,
                    hasSelectedModule: true,
                    artworkImage: audioViewModel.decodedArtwork
                ) {
                    audioViewModel.togglePlayback()
                } onSkipForward: {
                    audioViewModel.skipForward()
                }
                .onTapGesture {
                    expandMiniPlayer.toggle()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 8)
                // Positioned neatly directly over the native system bottom tab bar line
                .padding(.bottom, 54)
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: audioViewModel.selectedModule != nil)
        .onAppear { refreshEngineIfNeeded() }
        .onChange(of: wrapper.isReady) { _, isReady in if isReady { wrapper.refreshReadingEngine() } }
        .fullScreenCover(isPresented: $expandMiniPlayer) {
            ZStack(alignment: .top) {
                AudioBibleArtWorkView(viewModel: audioViewModel)
                
                Capsule()
                    .fill(.primary.secondary)
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 60 {
                                    expandMiniPlayer = false
                                }
                            }
                    )
            }
        }
#endif
    }
    
    // ─────────────────────────────────────────────────────────────────
    //  MAC SIDEBAR DEFINITION COMPONENT
    // ─────────────────────────────────────────────────────────────────
    #if os(macOS)
    private var macOSTabView: some View {
        TabView(selection: $wrapper.selectedSidebarItem) {
            Tab(value: SidebarItem.all, role: .search) {
                DetailView(selection: .all, viewModel: audioViewModel)
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            Tab(value: SidebarItem.study) {
                DetailView(selection: .study, viewModel: audioViewModel)
            } label: {
                Label(SidebarItem.study.title, systemImage: SidebarItem.study.icon)
            }
            
            Tab(value: SidebarItem.store) {
                DetailView(selection: .store, viewModel: audioViewModel)
            } label: {
                Label(SidebarItem.store.title, systemImage: SidebarItem.store.icon)
            }
            
            if sizeClass == .regular {
                TabSection("Tools") {
                    Tab(value: SidebarItem.audioBible) {
                        AudioBibleView(viewModel: audioViewModel)
                    } label: {
                        Label(SidebarItem.audioBible.title, systemImage: SidebarItem.audioBible.icon)
                    }
                    Tab(value: SidebarItem.bibleTimeline) {
                        DetailView(selection: .bibleTimeline, viewModel: audioViewModel)
                    } label: {
                        Label(SidebarItem.bibleTimeline.title, systemImage: SidebarItem.bibleTimeline.icon)
                    }
                }
            }
            
            if sizeClass == .regular {
                TabSection("Library") {
                    ForEach(getAvailableCategories(), id: \.self) { item in
                        Tab(item.title, systemImage: item.icon, value: item) {
                            DetailView(selection: item, viewModel: audioViewModel)
                        }
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onAppear { refreshEngineIfNeeded() }
        .onChange(of: wrapper.isReady) { _, isReady in if isReady { wrapper.refreshReadingEngine() } }
    }
    #endif
    
    // MARK: - Logic Helper Blocks
    private func refreshEngineIfNeeded() {
        if wrapper.isReady {
            wrapper.refreshReadingEngine()
        }
    }
    
    private func getAvailableCategories() -> [SidebarItem] {
        return SidebarItem.allCases.filter { item in
            let nonLibraryItems: [SidebarItem] = [.all, .study, .store, .bibleTimeline, .audioBible, .maps]
            guard !nonLibraryItems.contains(item) else { return false }
            return wrapper.installedModuleCategories.contains(item.title)
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
