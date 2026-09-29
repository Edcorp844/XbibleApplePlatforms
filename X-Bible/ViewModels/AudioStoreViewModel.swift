//
//  AudioStoreViewModel.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/10/26.
//

import SwiftUI
import XbibleEngine
import Combine

// Marking the class @MainActor guarantees all published property mutations
// happen safely on the main thread, resolving layout race-condition crashes.
@MainActor
final class AudioStoreViewModel: ObservableObject {
    @Published var availableModules: [RemoteAudioModuleInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let storeService = StoreApiService()
    private var trackingTask: Task<Void, Never>? = nil
    
    func loadCatalog() async {
        isLoading = true
        errorMessage = nil
        do {
            // FIX: Add 'try' back because the synchronous Rust function still returns a Result/throws errors
            self.availableModules = try storeService.loadCatalog()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func installModule(id: String) {
        trackingTask?.cancel()
        updateModuleProgress(id: id, progress: 0.0)
        
        let progressListener = StoreDownloadProgressListener(uniqueIdFilter: id)
        startProgressTrackingTask(for: id)
        
        // FIX: Route the blocking Rust block_on call off the cooperative async pool
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let localPath = try self.storeService.installModule(
                    moduleId: id,
                    progressListener: progressListener
                )
                print("Module successfully downloaded to: \(localPath)")
                
                // Jump back to the Main Actor to finalize UI status updates
                Task { @MainActor in
                    self.trackingTask?.cancel()
                    self.updateModuleStatusToInstalled(id: id)
                }
            } catch {
                Task { @MainActor in
                    self.trackingTask?.cancel()
                    self.errorMessage = error.localizedDescription
                    self.resetModuleStatus(id: id)
                }
            }
        }
    }
    
    // ─── PRIVATE TRACKING ORCHESTRATION ───
    
    /// Monitors internal catalog indices inside an isolated async polling process mapped to the MainActor context
    private func startProgressTrackingTask(for moduleId: String) {
        trackingTask = Task(priority: .medium) { @MainActor in
            while !Task.isCancelled {
                do {
                    // Poll at a 250ms cadence to mirror the engine throttle timing signature
                    try await Task.sleep(for: .seconds(0.25))
                    
                    let liveCatalog = self.storeService.getCachedCatalog()
                    
                    if let realTimeModule = liveCatalog.first(where: { $0.uniqueId == moduleId }) {
                        // Extract progress values natively from the wrapped variant configuration
                        if case .downloading(let progress) = realTimeModule.status {
                            self.updateModuleProgress(id: moduleId, progress: progress)
                        }
                        
                        if realTimeModule.isInstalled {
                            self.updateModuleStatusToInstalled(id: moduleId)
                            break
                        }
                    }
                } catch {
                    break
                }
            }
        }
    }
    
    // ─── STATE MANAGEMENT HELPERS ───
    
    private func updateModuleProgress(id: String, progress: Double) {
        if let index = availableModules.firstIndex(where: { $0.uniqueId == id }) {
            availableModules[index].status = .downloading(progress: progress)
        }
    }
    
    private func updateModuleStatusToInstalled(id: String) {
        if let index = availableModules.firstIndex(where: { $0.uniqueId == id }) {
            availableModules[index].status = .installed
            availableModules[index].isInstalled = true
        }
    }
    
    private func resetModuleStatus(id: String) {
        if let index = availableModules.firstIndex(where: { $0.uniqueId == id }) {
            availableModules[index].status = .idle
        }
    }
}
