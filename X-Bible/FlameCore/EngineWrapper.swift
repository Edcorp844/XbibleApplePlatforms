//
//  EngineWrapper.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import Foundation
import XbibleEngine
import Combine
import SwiftUI

class SwordEngineWrapper: ObservableObject {
    
    // MARK: - Engine
    
    /// Shared Rust engine instance for the entire app
    @Published var engine: XBibleEngine?
    
    /// Persistent task manager (catalog caching + background work)
    var storeTaskManager = StoreTaskManager()
    
    /// Global serial queue for ALL engine FFI calls (library is not thread-safe)
    let engineQueue = DispatchQueue(label: "com.xbible.engine-queue", qos: .userInitiated)
    
    @Published var isReady = false
    @Published var errorMessage: String?
    
    private static let initQueue = DispatchQueue(label: "com.xbible.engine-init")
    private static var isInitializing = false
    
    /// Bumped whenever the installed module list changes (forces views to refresh)
    @Published var engineVersion = 0
    
    // MARK: - Global Navigation & Selection State (all optionals)
    
    @Published var selectedSidebarItem: SidebarItem? = .study
    @Published var selectedModule: String?          // nil until a module is chosen
    @Published var selectedBook: String?            // nil until a book is chosen
    @Published var selectedChapter: Int?            // nil until a chapter is chosen
    
    /// Titles of categories that currently have at least one installed module
    @Published var installedModuleCategories: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        setupEngine()
        setupNotificationListeners()
    }
    
    // MARK: - Notifications
    
    private func setupNotificationListeners() {
        NotificationCenter.default.publisher(for: .installationStateChanged)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshReadingEngine()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Engine Lifecycle
    
    func setupEngine() {
        SwordEngineWrapper.initQueue.async {
            guard !SwordEngineWrapper.isInitializing else { return }
            SwordEngineWrapper.isInitializing = true
            
            do {
                let sharedEngine = XBibleEngine()
                
                DispatchQueue.main.async {
                    self.engine = sharedEngine
                    self.isReady = true
                    SwordEngineWrapper.isInitializing = false
                    
                    // First-time default selection (no hard-coded KJV)
                    self.ensureDefaultSelectionIfNeeded()
                }
            }
        }
    }
    
    // MARK: - Module / Book / Chapter Selection
    
    /// Ensures we always have a sensible default selection when possible.
    /// Prefers Bible modules, falls back to any available module.
    /// Never calls engine methods with nil values.
    func ensureDefaultSelectionIfNeeded() {
        guard let engine = self.engine else { return }
        
        // Already selected → nothing to do
        if selectedModule != nil { return }
        
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Prefer Bible modules, otherwise take the first module of any type
            let bibleModules = engine.getBibleModules()
            let candidate = bibleModules.first ?? engine.getAvailableModules().first
            
            guard let module = candidate else {
                // Nothing installed yet
                DispatchQueue.main.async {
                    self.selectedModule = nil
                    self.selectedBook = nil
                    self.selectedChapter = nil
                }
                return
            }
            
            let moduleName = module.name   // non-optional String
            
            // Safe call – moduleName is guaranteed non-nil
            let books = engine.getBooks(moduleName: moduleName)
            
            guard let firstBook = books.first else {
                DispatchQueue.main.async {
                    self.selectedModule = moduleName
                    self.selectedBook = nil
                    self.selectedChapter = nil
                }
                return
            }
            
            // firstBook.chapters is already available – take the first chapter number
            let firstChapterNumber = firstBook.chapters.first.map { Int($0.number) }
            
            DispatchQueue.main.async {
                self.selectedModule = moduleName
                self.selectedBook = firstBook.name
                self.selectedChapter = firstChapterNumber ?? 1
            }
        }
    }
    
    /// Open a specific module in the Study view
    func openModuleInStudy(_ module: SwordModule) {
        selectedModule = module.name
        selectedSidebarItem = .study
        
        // Optionally clear book/chapter so StudyView re-evaluates
        // selectedBook = nil
        // selectedChapter = nil
    }
    
    // MARK: - Refresh after install / uninstall
    
    func refreshReadingEngine() {
        engineQueue.async { [weak self] in
            guard let self = self, let engine = self.engine else { return }
            
            // 1. Tell the engine to re-scan installed modules
            _ = engine.refreshInstalledModules()
            
            // 2. Rebuild the set of active sidebar categories
            var activeTitles = Set<String>()
            
            if !engine.getBibleModules().isEmpty            { activeTitles.insert(SidebarItem.bible.title) }
            if !engine.getCommentaryModules().isEmpty       { activeTitles.insert(SidebarItem.commentary.title) }
            if !engine.getDictionaryModules().isEmpty       { activeTitles.insert(SidebarItem.dictionary.title) }
            if !engine.getLexiconModules().isEmpty          { activeTitles.insert(SidebarItem.lexicons.title) }
            if !engine.getGlossaryModules().isEmpty         { activeTitles.insert(SidebarItem.glossary.title) }
            if !engine.getDailyDevotionalModules().isEmpty  { activeTitles.insert(SidebarItem.dailyDevotional.title) }
            if !engine.getEssayModules().isEmpty            { activeTitles.insert(SidebarItem.essays.title) }
            if !engine.getBookModules().isEmpty             { activeTitles.insert(SidebarItem.generalBooks.title) }
            
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.installedModuleCategories = activeTitles
                    self.engineVersion += 1
                }
                
                // After a refresh we may now have modules – pick a default if needed
                self.ensureDefaultSelectionIfNeeded()
            }
        }
    }
    
    // MARK: - Paths
    
    func getSwordDataPath() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        let swordPath = appSupport.appendingPathComponent("org.flame.xbible")
        
        do {
            try FileManager.default.createDirectory(
                at: swordPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return swordPath
        } catch {
            print("Error creating directory: \(error)")
            return nil
        }
    }
}
