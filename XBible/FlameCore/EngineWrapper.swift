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
    // The actual Rust engine instance
    // Shared engine instance for the entire app
    @Published var engine: BibleEngine?
    
    // Persistent task manager to cache catalog and manage background tasks
    var storeTaskManager = StoreTaskManager()
    
    // Global serial queue for ALL engine FFI calls to ensure library-level thread safety
    let engineQueue = DispatchQueue(label: "com.xbible.engine-queue", qos: .userInitiated)
    
    @Published var isReady = false
    @Published var errorMessage: String?
    
    private static let initQueue = DispatchQueue(label: "com.xbible.engine-init")
    private static var isInitializing = false
    
    @Published var engineVersion = 0
    
    // Global Navigation & Selection State
    @Published var selectedSidebarItem: SidebarItem? = .study
    @Published var selectedModule: String = "KJV"
    @Published var selectedBook: String = "John"
    @Published var selectedChapter: Int = 1
    
    // Installed categories for the sidebar
    @Published var installedModuleCategories: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupEngine()
        setupNotificationListeners()
    }
    
    private func setupNotificationListeners() {
        NotificationCenter.default.publisher(for: .installationStateChanged)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main) // Batch multiple updates
            .sink { [weak self] _ in
                self?.refreshReadingEngine()
            }
            .store(in: &cancellables)
    }
    
    func refreshReadingEngine() {
        self.engineQueue.async { [weak self] in
            guard let self = self, let engine = self.engine else { return }
            
            // 1. Refresh the engine's internal module list
            engine.refreshInstalledModules()
            
            // 2. Update active categories
            var activeTitles = Set<String>()
            let allModules = engine.getAvailableModules()
            
            // Check standard fetchers
            if !engine.getBibleModules().isEmpty { activeTitles.insert(SidebarItem.bible.title) }
            if !engine.getCommentaryModules().isEmpty { activeTitles.insert(SidebarItem.commentary.title) }
            if !engine.getDictionaryModules().isEmpty { activeTitles.insert(SidebarItem.dictionary.title) }
            if !engine.getLexiconModules().isEmpty { activeTitles.insert(SidebarItem.lexicons.title) }
            if !engine.getGlossaryModules().isEmpty { activeTitles.insert(SidebarItem.glossary.title) }
            if !engine.getDailyDevotionalModules().isEmpty { activeTitles.insert(SidebarItem.dailyDevotional.title) }
            if !engine.getEssayModules().isEmpty { activeTitles.insert(SidebarItem.essays.title) }
            if !engine.getBookModules().isEmpty { activeTitles.insert(SidebarItem.generalBooks.title) }
            
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.installedModuleCategories = activeTitles
                    self.engineVersion += 1
                }
            }
        }
    }
    
    func openModuleInStudy(_ module: SwordModule) {
        self.selectedModule = module.name
        self.selectedSidebarItem = .study
        
        // Reset to first book if necessary, or keep current? 
        // For now, let's keep current book/chapter if they exist in the new module
        // StudyView handles this in updateBooks()
    }
    
    func setupEngine() {
        SwordEngineWrapper.initQueue.async {
            guard !SwordEngineWrapper.isInitializing else { return }
            SwordEngineWrapper.isInitializing = true
            
            do {
                let sharedEngine = BibleEngine()
                
                DispatchQueue.main.async {
                    self.engine = sharedEngine
                    self.isReady = true
                    SwordEngineWrapper.isInitializing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to initialize Bible engine."
                    SwordEngineWrapper.isInitializing = false
                }
            }
        }
    }
    
    func getSwordDataPath() -> URL? {
        // 1. Get the system Application Support directory
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // 2. Append your specific bundle identifier/folder name
        let swordPath = appSupport.appendingPathComponent("org.flame.xbible")
        
        // 3. Ensure the folder actually exists before you try to put data there
        do {
            try FileManager.default.createDirectory(at: swordPath, withIntermediateDirectories: true, attributes: nil)
            return swordPath
        } catch {
            print("Error creating directory: \(error)")
            return nil
        }
    }
}
