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
    @EnvironmentObject var studyViewModel: StudyViewModel
    @EnvironmentObject var storeViewModel: StoreViewModel

    private let coreAudioEngine: AudioEngine
    @StateObject private var audioViewModel: AudioBibleViewModel
    @State private var textConfigVM: TextConfigViewModel?
    
    @State private var expandMiniPlayer: Bool = false
    @State private var isFABExpanded: Bool = false
    @State private var customization = TabViewCustomization()
    
    init() {
        let engine = AudioEngine()
        self.coreAudioEngine = engine
        self._audioViewModel = StateObject(wrappedValue: AudioBibleViewModel(engine: engine))
    }
    
    var body: some View {
        Group {
            if let vm = textConfigVM {
                mainLayout
                    .environmentObject(vm)
            } else {
                ProgressView()
                    .onAppear {
                        if textConfigVM == nil {
                            textConfigVM = TextConfigViewModel(modelContext: modelContext)
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var mainLayout: some View {
#if os(macOS)
        // ─────────────────────────────────────────────
        // macOS – keep floating mini player as before
        // ─────────────────────────────────────────────
        macOSTabView
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioViewModel.selectedModule != nil)
            .onAppear { refreshEngineIfNeeded() }
            .onChange(of: wrapper.isReady) { _, isReady in
                if isReady { wrapper.refreshReadingEngine() }
            }
#else
        // ─────────────────────────────────────────────
        // iOS – use official bottom accessory
        // ─────────────────────────────────────────────
        TabView(selection: $wrapper.selectedSidebarItem) {
            if sizeClass == .compact {
                if wrapper.selectedSidebarItem == .study {
                    Tab(value: .none, role: .search) {
                    } label: {
                        Label("Tabs", systemImage: "square.on.square")
                            .symbolVariant(.none)
                    }
                    .badge(studyViewModel.tabs.count > 99 ? "99+" : "\(studyViewModel.tabs.count)")
                }
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
                    .customizationID("com.xbible.audio")
                    
                    Tab(value: SidebarItem.bibleTimeline) {
                        DetailView(selection: .bibleTimeline, viewModel: audioViewModel)
                    } label: {
                        Label(SidebarItem.bibleTimeline.title, systemImage: SidebarItem.bibleTimeline.icon)
                    }
                    .customizationID("com.xbible.timeline")
                }
                .customizationID("com.xbible.tools")
            } else {
                Tab(value: SidebarItem.tools) {
                    DetailView(selection: .tools, viewModel: audioViewModel)
                } label: {
                    Label(SidebarItem.tools.title, systemImage: SidebarItem.tools.icon)
                }
                .customizationID("com.xbible.tools")
            }
            
            if sizeClass == .regular {
                TabSection("Library") {
                    ForEach(getAvailableCategories(), id: \.self) { item in
                        Tab(item.title, systemImage: item.icon, value: item) {
                            DetailView(selection: item, viewModel: audioViewModel)
                        }
                        .customizationID("com.xbible.\(item.title.lowercased())")
                    }
                }
                .customizationID("com.xbible.library")
            } else {
                Tab(value: SidebarItem.all) {
                    DetailView(selection: .all, viewModel: audioViewModel)
                } label: {
                    Label(SidebarItem.all.title, systemImage: SidebarItem.all.icon)
                }
                .customizationID("com.xbible.library")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(.sidebar)
        // Official bottom accessory (iOS only)
        .tabViewBottomAccessory {
            if audioViewModel.selectedModule != nil {
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
                    expandMiniPlayer = true
                }
            }
        }
        .onAppear { refreshEngineIfNeeded() }
        .onChange(of: wrapper.isReady) { _, isReady in
            if isReady { wrapper.refreshReadingEngine() }
        }
        .onChange(of: wrapper.selectedSidebarItem) { oldValue, newValue in
            if newValue == nil {
                UITabBar.setAnimationsEnabled(false)
                wrapper.selectedSidebarItem = oldValue
                DispatchQueue.main.async {
                    UITabBar.setAnimationsEnabled(true)
                    studyViewModel.showTabOverview.toggle()
                }
            }
        }
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
    
    // ─────────────────────────────────────────────
    // macOS TabView + floating mini player
    // ─────────────────────────────────────────────
#if os(macOS)
    private var macOSTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $wrapper.selectedSidebarItem) {
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
                        .customizationID("com.xbible.audio")
                        
                        Tab(value: SidebarItem.bibleTimeline) {
                            DetailView(selection: .bibleTimeline, viewModel: audioViewModel)
                        } label: {
                            Label(SidebarItem.bibleTimeline.title, systemImage: SidebarItem.bibleTimeline.icon)
                        }
                        .customizationID("com.xbible.timeline")
                    }
                    .customizationID("com.xbible.tools")
                }
                
                if sizeClass == .regular {
                    TabSection("Library") {
                        ForEach(getAvailableCategories(), id: \.self) { item in
                            Tab(item.title, systemImage: item.icon, value: item) {
                                DetailView(selection: item, viewModel: audioViewModel)
                            }
                            .customizationID("com.xbible.\(item.title.lowercased())")
                        }
                    }
                    .customizationID("com.xbible.library")
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .tabViewCustomization($customization)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: audioViewModel.selectedModule != nil)
        .onAppear { refreshEngineIfNeeded() }
        .onChange(of: wrapper.isReady) { _, isReady in
            if isReady { wrapper.refreshReadingEngine() }
        }
        .sheet(isPresented: $expandMiniPlayer) {
            AudioBibleArtWorkView(viewModel: audioViewModel)
                .frame(minWidth: 400, minHeight: 500)
        }
    }
#endif
    
    // MARK: - Helpers
    
    private func refreshEngineIfNeeded() {
        if wrapper.isReady {
            wrapper.refreshReadingEngine()
        }
    }
    
    private func getAvailableCategories() -> [SidebarItem] {
        SidebarItem.allCases.filter { item in
            let nonLibraryItems: [SidebarItem] = [.all, .study, .store, .bibleTimeline, .audioBible, .maps]
            guard !nonLibraryItems.contains(item) else { return false }
            return wrapper.installedModuleCategories.contains(item.title)
        }
    }
}
