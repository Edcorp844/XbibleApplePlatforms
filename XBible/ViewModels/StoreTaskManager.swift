//
//  StoreTaskManager.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/22/26.
//

import Foundation
import XbibleEngine
import Combine

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
    private var installationQueue: [String] = []
    private var isProcessingQueue = false
    private var cancelledModules = Set<String>()
    
    private var cachedModules: [String: [XbibleEngine.SwordModule]] = [:]
    private var cachedSources: [XbibleEngine.ModuleSource]?
    
    private var lastProgressUpdate: Date = Date.distantPast
    private let progressUpdateThrottle: TimeInterval = 0.5  // Only send progress every 0.5 seconds
    
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
        installationQueue.append(moduleName)
        
        if !isProcessingQueue {
            processNextInstallation(engine: engine, source: source)
        }
    }
    
    private func processNextInstallation(engine: BibleEngine, source: String) {
        guard !installationQueue.isEmpty else {
            isProcessingQueue = false
            return
        }
        
        if let index = installationQueue.firstIndex(where: { $0 == cancelledModules.first }) {
            installationQueue.remove(at: index)
            if !installationQueue.isEmpty {
                processNextInstallation(engine: engine, source: source)
            }
            return
        }
        
        isProcessingQueue = true
        let moduleName = installationQueue[0]
        
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
            } else {
                self.messages.send(.installFailed(moduleName: moduleName))
            }
            
            if !self.installationQueue.isEmpty {
                self.installationQueue.removeFirst()
            }
            self.isProcessingQueue = false
            self.processNextInstallation(engine: engine, source: source)
        }
    }
    
    func cancelInstallation(moduleName: String) {
        cancelledModules.insert(moduleName)
        if let index = installationQueue.firstIndex(of: moduleName) {
            installationQueue.remove(at: index)
        }
    }
}
