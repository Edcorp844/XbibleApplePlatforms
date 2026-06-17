import Foundation
import XbibleEngine
import Combine
import SwiftData

enum EngineStep: Equatable {
    case initializing
    case fetchingSources(current: Int, total: Int, activeSource: String)
    case processingSelection
    case installingModules
    case failed(String)
    case finished
}

struct InstallTracker: Identifiable {
    let id = UUID()
    let moduleName: String
    var progress: Float
    var status: String
}

import Foundation
import XbibleEngine
import Combine
import SwiftData

class StoreTaskManager: ObservableObject {
    @Published var currentStep: EngineStep = .initializing
    @Published var installers: [InstallTracker] = []
    @Published var globalProgress: Float = 0.0
    
    let messages = PassthroughSubject<TaskMessage, Never>()
    
    // 📂 CHANNEL 1: Low-priority background sync lane (Prevents thread stalling)
    private var catalogSyncQueue = DispatchQueue(label: "com.xbible.catalog-sync-queue", qos: .background)
    
    // ⚡️ CHANNEL 2: Ultra-high-priority execution lane for instant user feedback
    private var userInteractionQueue = DispatchQueue(label: "com.xbible.user-interaction-queue", qos: .userInteractive)
    
    private var modelContext: ModelContext?
    private var engine: XBibleEngine?
    
    private var activeInstallTasks: [String: String] = [:] // [ModuleName: TaskId]
    private let activeTasksLock = NSRecursiveLock()
    
    func setup(modelContext: ModelContext, engine: XBibleEngine, queue: DispatchQueue? = nil) {
        self.modelContext = modelContext
        self.engine = engine
        
        startSynchronizationPipeline()
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    //  CHANNEL 1: CATALOG SYNCHRONIZATION (Low Priority Background Execution)
    // ─────────────────────────────────────────────────────────────────────────
    
    func startSynchronizationPipeline() {
        guard let engine = self.engine else { return }
        
        catalogSyncQueue.async { [weak self] in
            guard let self = self else { return }
            
            let sources = engine.getRemoteSources()
            if sources.isEmpty {
                self.updateStep(.failed("No remote sources configured."))
                return
            }
            
            let sourceStrings = sources.map { "\($0)" }
            self.fetchSourcesIncrementally(sources: sourceStrings, index: 0, total: sources.count)
        }
    }
    
    private func fetchSourcesIncrementally(sources: [String], index: Int, total: Int) {
        guard index < sources.count else {
            self.updateStep(.finished)
            return
        }
        
        catalogSyncQueue.async { [weak self] in
            guard let self = self, let engine = self.engine else { return }
            let sourceIdentifier = sources[index]
            
            print("📡 Syncing repository sequentially: \(sourceIdentifier)...")
            
            // Runs on the separate low priority catalog queue
            let modules = engine.fetchRemoteModules(sourceName: sourceIdentifier)
            
            DispatchQueue.main.async {
                let nextIndex = index + 1
                self.currentStep = .fetchingSources(current: nextIndex, total: total, activeSource: sourceIdentifier)
                self.globalProgress = Float(nextIndex) / Float(total)
                
                if !modules.isEmpty {
                    self.messages.send(.fetchCompleted(source: sourceIdentifier, modules: modules))
                } else {
                    self.messages.send(.fetchFailed(source: sourceIdentifier))
                }
                
                // Let the thread breathe so the high-priority queue can inject commands seamlessly
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
                    self.fetchSourcesIncrementally(sources: sources, index: nextIndex, total: total)
                }
            }
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    //  CHANNEL 2: TARGET ACTIONS (High Priority Interaction Lane)
    // ─────────────────────────────────────────────────────────────────────────
    
    func installModule(engine: XBibleEngine, source: String, moduleName: String, skipDatabase: Bool = false) {
        userInteractionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if engine.isModuleInstalled(moduleName: moduleName) {
                DispatchQueue.main.async {
                    if !skipDatabase { self.removePendingInstallation(moduleName: moduleName) }
                    self.messages.send(.installCompleted(moduleName: moduleName))
                }
                return
            }
            
            DispatchQueue.main.async {
                if !skipDatabase {
                    self.modelContext?.insert(PendingInstallation(moduleName: moduleName, source: source))
                    try? self.modelContext?.save()
                }
                self.messages.send(.installStarted(moduleName: moduleName))
            }
            
            // ⏳ Keep our safety wait gate to ensure the background sync stream doesn't clash
            if case .fetchingSources(_, _, let activeSource) = self.currentStep, activeSource == source {
                print("⏳ Source \(source) is currently busy syncing catalogues. Postponing installation start...")
                var retryCount = 0
                while case .fetchingSources(_, _, let activeSource) = self.currentStep, activeSource == source, retryCount < 20 {
                    Thread.sleep(forTimeInterval: 0.2)
                    retryCount += 1
                }
            }
            
            // 🛠️ CRITICAL FIX FOR -9 WRITE FAILURE:
            // Before calling install, we must force the C++ layer to refresh its internal
            // target installation pointer directory. This explicitly binds a writable path context.
            print("🔧 Initializing target directory permissions for \(moduleName)...")
            _ = engine.refreshInstalledModules()
            
            // Now fire the extraction task safely
            let taskId = engine.installModuleAsync(source: source, moduleName: moduleName)
            
            self.activeTasksLock.lock()
            self.activeInstallTasks[moduleName] = taskId
            self.activeTasksLock.unlock()
            
            while let status = engine.getTaskStatus(taskId: taskId), status.state == .running {
                let progressValue = status.progress
                
                DispatchQueue.main.async {
                    self.messages.send(.installProgress(
                        moduleName: moduleName,
                        progress: progressValue,
                        status: "Downloading",
                        downloadedBytes: 0,
                        totalBytes: 0
                    ))
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            self.activeTasksLock.lock()
            self.activeInstallTasks.removeValue(forKey: moduleName)
            self.activeTasksLock.unlock()
            
            let isSuccess = engine.isModuleInstalled(moduleName: moduleName)
            
            DispatchQueue.main.async {
                if isSuccess {
                    if !skipDatabase { self.removePendingInstallation(moduleName: moduleName) }
                    self.messages.send(.installCompleted(moduleName: moduleName))
                    print("✅ Module '\(moduleName)' successfully installed and registered!")
                } else {
                    print("🚨 Extraction pipeline failed with error code -9. Check file path system sandbox limits.")
                    self.messages.send(.installFailed(moduleName: moduleName))
                }
            }
        }
    }
    
    func refreshInstalledModules(completion: @escaping ([XbibleEngine.SwordModule]) -> Void) {
        userInteractionQueue.async { [weak self] in
            guard let self = self, let engine = self.engine else { return }
            let modules = engine.refreshInstalledModules()
            DispatchQueue.main.async {
                completion(modules)
            }
        }
    }
    
    func cancelInstallation(moduleName: String) {
        guard let engine = self.engine else { return }
        userInteractionQueue.async {
            self.activeTasksLock.lock()
            let targetTaskId = self.activeInstallTasks[moduleName]
            if let taskId = targetTaskId {
                engine.cancelTask(taskId: taskId)
                self.activeInstallTasks.removeValue(forKey: moduleName)
            }
            self.activeTasksLock.unlock()
            
            DispatchQueue.main.async {
                self.removePendingInstallation(moduleName: moduleName)
                self.messages.send(.installCancelled(moduleName: moduleName))
            }
        }
    }
    
    private func updateStep(_ step: EngineStep) {
        DispatchQueue.main.async {
            self.currentStep = step
        }
    }
    
    private func removePendingInstallation(moduleName: String) {
        let descriptor = FetchDescriptor<PendingInstallation>(predicate: #Predicate { $0.moduleName == moduleName })
        if let results = try? modelContext?.fetch(descriptor), let match = results.first {
            modelContext?.delete(match)
            try? modelContext?.save()
        }
    }
}
