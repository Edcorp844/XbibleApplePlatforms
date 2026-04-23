//
//  StoreTaskManager.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/22/26.
//

import Foundation
import XbibleEngine
import Combine
import SwiftData

extension Notification.Name {
    static let installationStateChanged = Notification.Name("installationStateChanged")
}

enum TaskMessage: Equatable {
    case sourcesUpdated([XbibleEngine.ModuleSource])
    case sourcesFailed
    case fetchStarted
    case fetchProgress(progress: Double, status: String, downloadedBytes: Int64, totalBytes: Int64)
    case fetchCompleted([XbibleEngine.SwordModule])
    case fetchFailed
    
    case installStarted(moduleName: String)
    case installProgress(moduleName: String, progress: Double, status: String, downloadedBytes: Int64, totalBytes: Int64)
    case installCompleted(moduleName: String)
    case installFailed(moduleName: String)
    case installCancelled(moduleName: String)
}

class StoreTaskManager: ObservableObject {
    let messages = PassthroughSubject<TaskMessage, Never>()
    
    private let queue = DispatchQueue(label: "com.xbible.store-task-manager", qos: .background)
    private let progressQueue = DispatchQueue(label: "com.xbible.store-task-manager.progress", qos: .utility)
    private var isFetching = false
    private var modelContext: ModelContext?
    
    // Changed queue to store tuples of (moduleName, source)
    private var installationQueue: [(moduleName: String, source: String)] = []
    private var isProcessingQueue = false
    private var cancelledModules = Set<String>()
    
    private var cachedModules: [String: [XbibleEngine.SwordModule]] = [:]
    private var cachedSources: [XbibleEngine.ModuleSource]?
    
    private var lastProgressUpdate: Date = Date.distantPast
    private let progressUpdateThrottle: TimeInterval = 0.5  // Only send progress every 0.5 seconds
    
    func setup(modelContext: ModelContext, engine: BibleEngine) {
        self.modelContext = modelContext
        
        // Initialize queue from SwiftData if empty
        if installationQueue.isEmpty && !isProcessingQueue {
            resumePendingInstallations(engine: engine)
        }
    }
    
    private func resumePendingInstallations(engine: BibleEngine) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<PendingInstallation>(sortBy: [SortDescriptor(\.addedAt)])
        if let pending = try? context.fetch(descriptor) {
            for item in pending {
                if !installationQueue.contains(where: { $0.moduleName == item.moduleName }) {
                    installationQueue.append((item.moduleName, item.source))
                    messages.send(.installStarted(moduleName: item.moduleName))
                }
            }
            
            if !installationQueue.isEmpty && !isProcessingQueue {
                processNextInstallation(engine: engine)
            }
        }
    }
    
    private func removePendingInstallation(moduleName: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<PendingInstallation>(predicate: #Predicate { $0.moduleName == moduleName })
        if let results = try? context.fetch(descriptor), let match = results.first {
            context.delete(match)
            try? context.save()
        }
    }
    
    func fetchSources(engine: BibleEngine) {
        if let cached = cachedSources {
            messages.send(.sourcesUpdated(cached))
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let sources = engine.getRemoteSourcesWithDetails()
            self.cachedSources = sources
            self.messages.send(.sourcesUpdated(sources))
        }
    }
    
    func fetchModules(engine: BibleEngine, source: String) {
        guard !isFetching else { return }
        
        if let cached = cachedModules[source] {
            messages.send(.fetchCompleted(cached))
            return
        }
        
        isFetching = true
        messages.send(.fetchStarted)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let progressTimer = DispatchSource.makeTimerSource(queue: self.progressQueue)
            progressTimer.schedule(deadline: .now(), repeating: .milliseconds(500))
            progressTimer.setEventHandler {
                let now = Date()
                guard now.timeIntervalSince(self.lastProgressUpdate) >= self.progressUpdateThrottle else {
                    return
                }
                self.lastProgressUpdate = now
                let d = engine.getDownloadProgressDetails()
                self.messages.send(.fetchProgress(
                    progress: d.progress,
                    status: d.status,
                    downloadedBytes: d.downloadedBytes,
                    totalBytes: d.totalBytes
                ))
            }
            progressTimer.resume()
            
            let modules = engine.fetchRemoteModules(sourceName: source)
            
            progressTimer.cancel()
            
            self.cachedModules[source] = modules
            self.messages.send(.fetchCompleted(modules))
            self.isFetching = false
        }
    }
    
    func refreshModules(engine: BibleEngine, source: String) {
        // Force clear cache and fetch again
        cachedModules.removeValue(forKey: source)
        fetchModules(engine: engine, source: source)
    }
    
    func installModule(engine: BibleEngine, source: String, moduleName: String) {
        // Persist to SwiftData
        if let context = modelContext {
            let pending = PendingInstallation(moduleName: moduleName, source: source)
            context.insert(pending)
            try? context.save()
        }
        
        if !installationQueue.contains(where: { $0.moduleName == moduleName }) {
            installationQueue.append((moduleName, source))
        }
        
        if !isProcessingQueue {
            processNextInstallation(engine: engine)
        }
    }
    
    private func processNextInstallation(engine: BibleEngine) {
        guard !installationQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        
        if let index = installationQueue.firstIndex(where: { $0.moduleName == cancelledModules.first }) {
            installationQueue.remove(at: index)
            if !installationQueue.isEmpty {
                processNextInstallation(engine: engine)
            }
            return
        }
        
        isProcessingQueue = true
        let task = installationQueue[0]
        let moduleName = task.moduleName
        let source = task.source
        
        messages.send(.installStarted(moduleName: moduleName))
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Start progress polling on background thread with throttled updates
            var lastUpdate = Date()
            let progressTimer = DispatchSource.makeTimerSource(queue: self.progressQueue)
            progressTimer.schedule(deadline: .now(), repeating: .milliseconds(300))  // Poll every 300ms
            progressTimer.setEventHandler {
                // Throttle updates to not more than every 0.5 seconds
                if Date().timeIntervalSince(lastUpdate) >= 0.5 {
                    let d = engine.getDownloadProgressDetails()
                    self.messages.send(.installProgress(
                        moduleName: moduleName,
                        progress: d.progress,
                        status: d.status,
                        downloadedBytes: d.downloadedBytes,
                        totalBytes: d.totalBytes
                    ))
                    lastUpdate = Date()
                }
            }
            progressTimer.resume()
            
            // Install module (heavy operation on background thread)
            let result = engine.installModuleWithProgress(source: source, moduleName: moduleName)
            
            progressTimer.cancel()
            
            // Check if was cancelled
            if self.cancelledModules.contains(moduleName) {
                self.messages.send(.installCancelled(moduleName: moduleName))
                self.cancelledModules.remove(moduleName)
            } else if result != 0 {
                self.messages.send(.installCompleted(moduleName: moduleName))
                DispatchQueue.main.async { self.removePendingInstallation(moduleName: moduleName) }
            } else {
                self.messages.send(.installFailed(moduleName: moduleName))
                DispatchQueue.main.async { self.removePendingInstallation(moduleName: moduleName) }
            }
            
            if !self.installationQueue.isEmpty && self.installationQueue.first?.moduleName == moduleName {
                self.installationQueue.removeFirst()
            }
            self.isProcessingQueue = false
            self.processNextInstallation(engine: engine)
        }
    }
    
    func cancelInstallation(moduleName: String) {
        cancelledModules.insert(moduleName)
        removePendingInstallation(moduleName: moduleName)
        if let index = installationQueue.firstIndex(where: { $0.moduleName == moduleName }) {
            installationQueue.remove(at: index)
        }
    }
}
