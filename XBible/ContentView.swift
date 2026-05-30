//
//  ContentView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/20/26.
//

import SwiftUI
import SwiftData
import XbibleEngine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var wrapper: SwordEngineWrapper
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. The Global TabView managing the Sidebar Navigation Layout
            TabView(selection: $wrapper.selectedSidebarItem) {
                
                // --- MAIN SECTION ---
                Tab("Study", systemImage: "book", value: SidebarItem.study) {
                    DetailView(selection: .study)
                }
                
                Tab("Store", systemImage: "cart", value: SidebarItem.store) {
                    DetailView(selection: .store)
                }
                
                // --- TOOLS SECTION ---
                TabSection("Tools") {
                    Tab("Timeline", systemImage: "calendar.day.timeline.left", value: SidebarItem.bibleTimeline) {
                        DetailView(selection: .bibleTimeline)
                    }
                    Tab("Audio Bible", systemImage: "speaker.wave.2", value: SidebarItem.audioBible) {
                        DetailView(selection: .audioBible)
                    }
                    Tab("Biblical Maps", systemImage: "map", value: SidebarItem.maps) {
                        DetailView(selection: .maps)
                    }
                }
                
                // --- LIBRARY SECTION (Dynamic) ---
                TabSection("Library") {
                    ForEach(getAvailableCategories(), id: \.self) { item in
                        Tab(item.title, systemImage: item.icon, value: item) {
                            DetailView(selection: item)
                        }
                    }
                }
            }
            // 2. Instructs macOS/iPadOS to render this TabView as a standard Sidebar split layout
            .tabViewStyle(.sidebarAdaptable)
                
        }
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

// MARK: - Custom UI Components
