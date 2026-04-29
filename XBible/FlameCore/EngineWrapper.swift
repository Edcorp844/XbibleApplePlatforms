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
        // No need to recreate the engine, just refresh its internal module list
        // if the engine supports it, or we can just trigger a UI refresh.
        // For SWORD, usually we need to re-scan the mods.d directory.
        self.engineQueue.async { [weak self] in
            self?.engine?.refreshInstalledModules()
            DispatchQueue.main.async {
                self?.engineVersion += 1
                self?.objectWillChange.send()
            }
        }
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
