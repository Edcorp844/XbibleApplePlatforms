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
    
    @State private var installedModuleCategories: Set<String> = []
    
    var body: some View {
        NavigationSplitView {
            List(selection: $wrapper.selectedSidebarItem) {
                
                // --- MAIN SECTION ---
                Section {
                    NavigationLink(value: SidebarItem.study) {
                        Label("Study", systemImage: "book")
                    }
                    NavigationLink(value: SidebarItem.store) {
                        Label("Store", systemImage: "cart")
                    }
                }
                .listRowSeparator(.hidden)

                // --- TOOLS SECTION (Persistent & Collapsible) ---
                Section(header: SidebarHeader(title: "Tools")) {
                    NavigationLink(value: SidebarItem.bibleTimeline) {
                        Label("Timeline", systemImage: "calendar.day.timeline.left")
                    }
                    NavigationLink(value: SidebarItem.audioBible) {
                        Label("Audio Bible", systemImage: "speaker.wave.2")
                    }
                    NavigationLink(value: SidebarItem.maps) {
                        Label("Biblical Maps", systemImage: "map")
                    }
                }

                // --- LIBRARY SECTION (Dynamic based on installed modules) ---
                Section(header: SidebarHeader(title: "Library")) {
                    let availableCategories = getAvailableCategories()
                    ForEach(availableCategories, id: \.self) { item in
                        NavigationLink(value: item) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("XBible")
        } detail: {
            DetailView(selection: wrapper.selectedSidebarItem)
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
        // Filter SidebarItem cases to only include those with installed modules
        return SidebarItem.allCases.filter { item in
            let nonLibraryItems: [SidebarItem] = [.all, .study, .store, .bibleTimeline, .audioBible, .maps]
            guard !nonLibraryItems.contains(item) else { return false }
            
            return wrapper.installedModuleCategories.contains(item.title)
        }
    }
}

// MARK: - Custom UI Components

struct SidebarHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
    }
}


#Preview{
    let engineWrapper = SwordEngineWrapper()
    ContentView()
        .environmentObject(engineWrapper)
}
