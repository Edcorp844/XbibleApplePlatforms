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
    @Published var engine: BibleEngine?
    @Published var isReady = false
    @Published var errorMessage: String?
    
    init() {
        setupEngine()
    }
    
    func setupEngine() {
        // Run on background thread so the UI doesn't freeze during
        // SWORD initialization (which can be slow)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let newEngine = BibleEngine()
                let remote = newEngine.getRemoteSourcesWithDetails()
                print("modules : \(remote.count)")
                DispatchQueue.main.async {
                    self.engine = newEngine
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
