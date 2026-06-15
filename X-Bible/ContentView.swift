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
        //  iOS MOBILE ARCHITECTURE (Direct TabView Hierarchy Root Layout)
        // ─────────────────────────────────────────────────────────────────
        TabView(selection: $wrapper.selectedSidebarItem) {
            Tab(value: SidebarItem.study) {
                NavigationSplitView {
                    DetailView(selection: .study, viewModel: audioViewModel)
                } detail: {
                    Text("Select Scripture Section")
                }
                .navigationSplitViewStyle(.automatic)
            } label: {
                Label("Study", systemImage: "book")
            }
            
            Tab(value: SidebarItem.store) {
                NavigationSplitView {
                    DetailView(selection: .store, viewModel: audioViewModel)
                } detail: {
                    Text("Select Module to Download")
                }
                .navigationSplitViewStyle(.automatic)
            } label: {
                Label("Store", systemImage: "cart")
            }
            
            Tab(value: SidebarItem.audioBible) {
                NavigationSplitView {
                    ToolsView(audioViewModel: audioViewModel)
                } detail: {
                    Text("Select Tool Matrix")
                }
                .navigationSplitViewStyle(.automatic)
            } label: {
                Label("Tools", systemImage: "ellipsis.rectangle")
            }
            
            Tab(value: SidebarItem.all) {
                NavigationSplitView {
                    DetailView(selection: .all, viewModel: audioViewModel)
                } detail: {
                    Text("Select Library Book")
                }
                .navigationSplitViewStyle(.automatic)
            } label: {
                Label("Library", systemImage: "books.vertical")
            }
            
            Tab(value: SidebarItem.all, role: .search) {
                NavigationSplitView {
                    DetailView(selection: .all, viewModel: audioViewModel)
                } detail: {
                    Text("Select Library Book")
                }
                .navigationSplitViewStyle(.automatic)
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
        // FIXED: Route via an explicit accessory structural bridge view
        // to isolate layout graph modifications away from ContentView root body
        .if(audioViewModel.selectedModule != nil) { view in
            view.tabViewBottomAccessory {
                AudioMiniPayer(
                    displayTitle: audioViewModel.selectedModule?.metadata?.displayTitle ?? "Audio Chapter",
                    activeLyricTitle:audioViewModel.currentActiveTitle,
                    isPlaying:audioViewModel.isPlaying, // Maps safely to our stable primitive boolean
                    hasSelectedModule: audioViewModel.selectedModule != nil,
                    artworkImage: audioViewModel.decodedArtwork
                ) {
                    audioViewModel.togglePlayback()
                } onSkipForward: {
                    audioViewModel.skipForward()
                }.onTapGesture {
                    expandMiniPlayer.toggle()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewStyle(.sidebarAdaptable)
        .onAppear { refreshEngineIfNeeded() }
        .onChange(of: wrapper.isReady) { _, isReady in if isReady { wrapper.refreshReadingEngine() } }
        .fullScreenCover(isPresented: $expandMiniPlayer) {
            ZStack(alignment: .top) {
                // Core View Layer
                AudioBibleArtWorkView(viewModel: audioViewModel)
                
                // Drag Indicator Capsule with an implicit drag gesture
                Capsule()
                    .fill(.primary.secondary)
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)
                    .contentShape(Rectangle()) // Makes the entire top area grabbable
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 60 { // Detect pulling down
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
            Tab("Study", systemImage: "book", value: SidebarItem.study) {
                NavigationSplitView {
                    DetailView(selection: .study, viewModel: audioViewModel)
                } detail: {
                    Text("Select Scripture Section")
                }
            }
            
            Tab("Store", systemImage: "cart", value: SidebarItem.store) {
                NavigationSplitView {
                    DetailView(selection: .store, viewModel: audioViewModel)
                } detail: {
                    Text("Select Module to Download")
                }
            }
            
            TabSection("Tools") {
                Tab("Timeline", systemImage: "calendar.day.timeline.left", value: SidebarItem.bibleTimeline) {
                    DetailView(selection: .bibleTimeline, viewModel: audioViewModel)
                }
                Tab("Audio Bible", systemImage: "speaker.wave.2", value: SidebarItem.audioBible) {
                    DetailView(selection: .audioBible, viewModel: audioViewModel)
                }
                Tab("Biblical Maps", systemImage: "map", value: SidebarItem.maps) {
                    DetailView(selection: .maps, viewModel: audioViewModel)
                }
            }
            
            TabSection("Library") {
                ForEach(getAvailableCategories(), id: \.self) { item in
                    Tab(item.title, systemImage: item.icon, value: item) {
                        DetailView(selection: item, viewModel: audioViewModel)
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
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
