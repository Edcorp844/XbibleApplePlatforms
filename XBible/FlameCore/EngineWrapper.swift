//
//  EngineWrapper.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import Foundation
import XbibleEngine
import Combine

class SwordEngineWrapper: ObservableObject {
    // The actual Rust engine instance
    // Reading engine for Study View
    @Published var engine: BibleEngine?
    
    // Management engine for Store and installations
    @Published var managementEngine: BibleEngine?
    
    // Persistent task manager to cache catalog and manage background tasks
    var storeTaskManager = StoreTaskManager()
    
    @Published var isReady = false
    @Published var errorMessage: String?
    
    // Track engine version to trigger UI refreshes without requiring BibleEngine to be Equatable
    @Published var engineVersion = 0
    
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
        // Re-initialize only the reading engine to pick up new modules
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newReadingEngine = BibleEngine()
            DispatchQueue.main.async {
                self?.engine = newReadingEngine
                self?.engineVersion += 1 // Trigger observers
                // Triggering a change notification for observers
                self?.objectWillChange.send()
            }
        }
    }
    
    func setupEngine() {
        // Run on background thread so the UI doesn't freeze during
        // SWORD initialization (which can be slow)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let readingEngine = BibleEngine()
                let mgmtEngine = BibleEngine()
                
                DispatchQueue.main.async {
                    self.engine = readingEngine
                    self.managementEngine = mgmtEngine
                    self.isReady = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to initialize Bible engine."
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
