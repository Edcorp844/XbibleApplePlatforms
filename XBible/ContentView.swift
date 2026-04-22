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
    
    // SwiftData Query for persisted sidebar customization
    @Query(sort: \SidebarConfiguration.createdAt) private var configs: [SidebarConfiguration]
    
    @State private var selectedItem: SidebarItem? = .study
    @State private var showingAddCategory = false
    @State private var installedModuleCategories: Set<String> = []
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                
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
                Section(header: LibraryHeader(title: "Library", onAdd: { showingAddCategory = true })) {
                    NavigationLink(value: SidebarItem.all) {
                        Label("All Library", systemImage: "books.vertical")
                    }
                    
                    // Dynamically show all categories that have installed modules
                    let availableCategories = getAvailableCategories()
                    ForEach(availableCategories, id: \.self) { item in
                        NavigationLink(value: item) {
                            Label(item.title, systemImage: item.icon)
                        }
                        .contextMenu {
                            // Only show remove option for pinned categories
                            if let config = configs.first, config.pinnedCategories.contains(item.title) {
                                Button(role: .destructive) {
                                    removeCategory(item.title)
                                } label: {
                                    Label("Remove from Sidebar", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                    
                    // Show pinned categories that might not have modules (for backwards compatibility)
                    if let config = configs.first {
                        ForEach(config.pinnedCategories, id: \.self) { catName in
                            if let item = SidebarItem.fromTitle(catName), !availableCategories.contains(item) {
                                NavigationLink(value: item) {
                                    Label(item.title, systemImage: item.icon)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        removeCategory(catName)
                                    } label: {
                                        Label("Remove from Sidebar", systemImage: "minus.circle")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("XBible")
        } detail: {
            DetailView(selection: selectedItem)
        }
        // UI for adding new categories
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet()
        }
        .onAppear(perform: ensureConfigExists)
        .onChange(of: wrapper.isReady) { _, isReady in
            if isReady {
                updateInstalledCategories()
            }
        }
        .onChange(of: selectedItem) { _ in
            // Refresh categories when switching views (in case modules were installed/uninstalled)
            if wrapper.isReady {
                updateInstalledCategories()
            }
        }
    }
    
    // MARK: - Logic
    
    private func ensureConfigExists() {
        if configs.isEmpty {
            let initialConfig = SidebarConfiguration(pinnedCategories: ["Biblical Texts"])
            modelContext.insert(initialConfig)
        }
    }
    
    private func getAvailableCategories() -> [SidebarItem] {
        // Filter SidebarItem cases to only include those with installed modules
        return SidebarItem.allCases.filter { item in
            let nonLibraryItems: [SidebarItem] = [.all, .study, .store, .bibleTimeline, .audioBible, .maps]
            guard !nonLibraryItems.contains(item) else { return false }
            
            return installedModuleCategories.contains(item.title)
        }
    }
    
    private func updateInstalledCategories() {
        guard let engine = wrapper.engine else { return }
        
        let allModules = engine.getAvailableModules()
        let installedModules = allModules.filter { engine.isModuleInstalled(moduleName: $0.name) }
        let categories = Set(installedModules.map { $0.category })
        
        installedModuleCategories = categories
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

struct LibraryHeader: View {
    let title: String
    let onAdd: () -> Void
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}


// MARK: - Sidebar Item Definition

enum SidebarItem: Hashable, CaseIterable  {
    case study, store, all, bible, commentary, dictionary, glossary, lexicons, dailyDevotional, essays, generalBooks, unorthodox, bibleTimeline, audioBible, maps
    
    var title: String {
        switch self {
        case .study: return "Study"
        case .store: return "Store"
        case .all: return "All Library"
        case .bible: return "Biblical Texts"
        case .commentary: return "Commentaries"
        case .dictionary: return "Dictionaries"
        case .lexicons: return "Lexicons"
        case .dailyDevotional: return "Daily Devotionals"
        case .bibleTimeline: return "Timeline"
        case .audioBible: return "Audio Bible"
        case .maps: return "Maps"
        default: return String(describing: self).capitalized
        }
    }
    
    var icon: String {
        switch self {
        case .study: return "book"
        case .store: return "cart"
        case .all: return "books.vertical"
        case .bible: return "book.closed"
        case .commentary: return "text.quote"
        case .dictionary: return "character.book.closed"
        case .lexicons: return "abc"
        case .bibleTimeline: return "calendar.day.timeline.left"
        case .audioBible: return "speaker.wave.2"
        case .maps: return "map"
        default: return "circle"
        }
    }
    
    static func fromTitle(_ title: String) -> SidebarItem? {
        return allCases.first(where: { $0.title == title })
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [SidebarConfiguration]
    
    var body: some View {
        NavigationStack {
            List {
                // Filter: Only show items that have actual modules in the engine
                let available = SidebarItem.allCases.filter { item in
                    let nonLibraryItems: [SidebarItem] = [.all, .study, .store, .bibleTimeline, .audioBible, .maps]
                    guard !nonLibraryItems.contains(item) else { return false }
                    
                    // Check if engine has any modules for this category string
                    let hasModules = !(wrapper.engine?.getAvailableModules().filter({ $0.category == item.title }).isEmpty ?? true)
                    return hasModules
                }
                
                if available.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.slash").font(.largeTitle).opacity(0.2)
                        Text("No installed modules found for other categories.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ForEach(available, id: \.self) { item in
                        Button {
                            if let config = configs.first, !config.pinnedCategories.contains(item.title) {
                                config.pinnedCategories.append(item.title)
                            }
                            dismiss()
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            }
            .navigationTitle("Add to Sidebar")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .frame(width: 320, height: 450)
    }
}
