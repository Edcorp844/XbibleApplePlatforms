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
    
    @State private var selectedItem: SidebarItem? = .study
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
            DetailView(selection: selectedItem)
        }
        .onAppear {
            if wrapper.isReady {
                updateInstalledCategories()
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .installationStateChanged)) { _ in
            // Add a small delay to ensure the engine has finished writing to disk
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if wrapper.isReady {
                    withAnimation(.spring()) {
                        updateInstalledCategories()
                    }
                }
            }
        }
    }
    
    // MARK: - Logic
    
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            var activeTitles = Set<String>()
            
            let allInstalled = engine.getAvailableModules().filter { engine.isModuleInstalled(moduleName: $0.name) }
            
            for module in allInstalled {
                let cat = module.category.lowercased()
                if cat.contains("bible") { activeTitles.insert(SidebarItem.bible.title) }
                else if cat.contains("commentar") { activeTitles.insert(SidebarItem.commentary.title) }
                else if cat.contains("dictionar") { activeTitles.insert(SidebarItem.dictionary.title) }
                else if cat.contains("lexicon") { activeTitles.insert(SidebarItem.lexicons.title) }
                else if cat.contains("glossar") { activeTitles.insert(SidebarItem.glossary.title) }
                else if cat.contains("devotion") { activeTitles.insert(SidebarItem.dailyDevotional.title) }
                else if cat.contains("essay") { activeTitles.insert(SidebarItem.essays.title) }
                else if cat.contains("unorthodox") || cat.contains("cult") { activeTitles.insert(SidebarItem.unorthodox.title) }
                else { activeTitles.insert(SidebarItem.generalBooks.title) } // Everything else goes to "Others"
            }
            
            // Double check standard fetchers
            if !engine.getBibleModules().isEmpty { activeTitles.insert(SidebarItem.bible.title) }
            if !engine.getCommentaryModules().isEmpty { activeTitles.insert(SidebarItem.commentary.title) }
            if !engine.getDictionaryModules().isEmpty { activeTitles.insert(SidebarItem.dictionary.title) }
            if !engine.getLexiconModules().isEmpty { activeTitles.insert(SidebarItem.lexicons.title) }
            if !engine.getGlossaryModules().isEmpty { activeTitles.insert(SidebarItem.glossary.title) }
            if !engine.getDailyDevotionalModules().isEmpty { activeTitles.insert(SidebarItem.dailyDevotional.title) }
            if !engine.getEssayModules().isEmpty { activeTitles.insert(SidebarItem.essays.title) }
            if !engine.getBookModules().isEmpty { activeTitles.insert(SidebarItem.generalBooks.title) }
            
            DispatchQueue.main.async {
                withAnimation {
                    self.installedModuleCategories = activeTitles
                }
            }
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


// MARK: - Sidebar Item Definition

enum SidebarItem: Hashable, CaseIterable, Equatable  {
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
        case .glossary: return "Glossaries"
        case .dailyDevotional: return "Daily Devotionals"
        case .essays: return "Essays"
        case .generalBooks: return "Others"
        case .unorthodox: return "Cults"
        case .bibleTimeline: return "Timeline"
        case .audioBible: return "Audio Bible"
        case .maps: return "Maps"
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
        case .glossary: return "character.book.closed"
        case .lexicons: return "abc"
        case .dailyDevotional: return "sun.max"
        case .essays: return "text.justify.left"
        case .generalBooks: return "books.vertical"
        case .unorthodox: return "exclamationmark.triangle"
        case .bibleTimeline: return "calendar.day.timeline.left"
        case .audioBible: return "speaker.wave.2"
        case .maps: return "map"
        }
    }
}


#Preview{
    let engineWrapper = SwordEngineWrapper()
    ContentView()
        .environmentObject(engineWrapper)
}
