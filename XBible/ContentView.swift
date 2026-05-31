//
//  ContentView.swift
//  XBible
//
import SwiftUI
import SwiftData
import XbibleEngine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var wrapper: SwordEngineWrapper
    
    private let coreAudioEngine: AudioEngine
    @StateObject private var audioViewModel: AudioBibleViewModel
    
    init() {
        let engine = AudioEngine()
        self.coreAudioEngine = engine
        self._audioViewModel = StateObject(wrappedValue: AudioBibleViewModel(engine: engine))
    }
    
    var body: some View {
        // Removed global ZStack wrapper so the TabView handles window-wide splitting natively
        TabView(selection: $wrapper.selectedSidebarItem) {
            
            // --- MAIN SECTION ---
            Tab("Study", systemImage: "book", value: SidebarItem.study) {
                DetailWrapperView(selection: .study, audioViewModel: audioViewModel)
            }
            
            Tab("Store", systemImage: "cart", value: SidebarItem.store) {
                DetailWrapperView(selection: .store, audioViewModel: audioViewModel)
            }
            
            // --- TOOLS SECTION ---
            TabSection("Tools") {
                Tab("Timeline", systemImage: "calendar.day.timeline.left", value: SidebarItem.bibleTimeline) {
                    DetailWrapperView(selection: .bibleTimeline, audioViewModel: audioViewModel)
                }
                Tab("Audio Bible", systemImage: "speaker.wave.2", value: SidebarItem.audioBible) {
                    DetailWrapperView(selection: .audioBible, audioViewModel: audioViewModel)
                }
                Tab("Biblical Maps", systemImage: "map", value: SidebarItem.maps) {
                    DetailWrapperView(selection: .maps, audioViewModel: audioViewModel)
                }
            }
            
            // --- LIBRARY SECTION (Dynamic) ---
            TabSection("Library") {
                ForEach(getAvailableCategories(), id: \.self) { item in
                    Tab(item.title, systemImage: item.icon, value: item) {
                        DetailWrapperView(selection: item, audioViewModel: audioViewModel)
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onAppear {
            if wrapper.isReady {
                wrapper.refreshReadingEngine()
            }
        }
        .onChange(of: wrapper.isReady) { _, isReady in
            if isReady {
                wrapper.refreshReadingEngine()
            }
        }
    }
    
    // MARK: - Logic
    private func getAvailableCategories() -> [SidebarItem] {
        return SidebarItem.allCases.filter { item in
            let nonLibraryItems: [SidebarItem] = [.all, .study, .store, .bibleTimeline, .audioBible, .maps]
            guard !nonLibraryItems.contains(item) else { return false }
            return wrapper.installedModuleCategories.contains(item.title)
        }
    }
}
