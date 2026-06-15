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

class StoreTaskManager: ObservableObject {
    @Published var currentStep: EngineStep = .initializing
    @Published var installers: [InstallTracker] = []
    @Published var globalProgress: Float = 0.0
    
    let messages = PassthroughSubject<TaskMessage, Never>()
    
    private var queue = DispatchQueue(label: "com.xbible.store-task-manager", qos: .userInitiated)
    
    private var modelContext: ModelContext?
    private var engine: XBibleEngine?
    
    private var fetchingSources = Set<String>()
    private var cachedModules: [String: [XbibleEngine.SwordModule]] = [:]
    private var cachedSources: [XbibleEngine.ModuleSource]?
    
    /// Thread-safe localized tracking registry mapping active module components to underlying engine tokens
    private var activeInstallTasks: [String: String] = [:] // [ModuleName: TaskId]
    
    func setup(modelContext: ModelContext, engine: XBibleEngine, queue: DispatchQueue? = nil) {
        if let sharedQueue = queue {
            self.queue = sharedQueue
        }
        self.modelContext = modelContext
        self.engine = engine
        
        // Kick off the unified parallel loading pipeline
        startSynchronizationPipeline()
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    //  UNIFIED CONCURRENT SYNCHRONIZATION WORKFLOW (Direct Rust Architecture)
    // ─────────────────────────────────────────────────────────────────────────
    
        func startSynchronizationPipeline() {
            guard let engine = self.engine else { return }
            
            queue.async { [weak self] in
                guard let self = self else { return }
                
                // 1. Structural Read of Remote Repositories
                let sources = engine.getRemoteSources()
                let totalSources = sources.count
                
                if sources.isEmpty {
                    self.updateStep(.failed("No remote sources are configured in the engine context."))
                    return
                }
                
                let modulesLock = NSLock()
                let counterLock = NSLock()
                var aggregatedModules: [XbibleEngine.SwordModule] = []
                var finishedCount = 0
                
                let fetchGroup = DispatchGroup()
                
                // 2. Spawn Workers to Pull Remote Catalogs Concurrently
                // 2. Pull Remote Catalogs Sequentially for Maximum FFI Stability
                            for source in sources {
                                let sourceIdentifier = "\(source)"
                                
                                // Keep execution context entirely on our isolated background queue
                                // This prevents slamming the Rust UniFFI layer simultaneously across threads
                                autoreleasepool {
                                    print("📡 Syncing repository: \(sourceIdentifier)...")
                                    
                                    // Call the engine method safely within our controlled sequential flow
                                    let modules = engine.fetchRemoteModules(sourceName: source)
                                    
                                    if !modules.isEmpty {
                                        modulesLock.lock()
                                        aggregatedModules.append(contentsOf: modules)
                                        modulesLock.unlock()
                                        
                                        // Push intermediate results live to the UI immediately upon success!
                                        DispatchQueue.main.async {
                                            self.messages.send(.fetchCompleted(source: sourceIdentifier, modules: modules))
                                        }
                                    } else {
                                        print("⚠️ Source returned zero modules or skipped: \(sourceIdentifier)")
                                        DispatchQueue.main.async {
                                            self.messages.send(.fetchFailed(source: sourceIdentifier))
                                        }
                                    }
                                    
                                    counterLock.lock()
                                    finishedCount += 1
                                    let currentFinished = finishedCount
                                    counterLock.unlock()
                                    
                                    // Dispatch state parameters directly up to Main Actor UI observers
                                    DispatchQueue.main.async {
                                        self.currentStep = .fetchingSources(current: currentFinished, total: totalSources, activeSource: sourceIdentifier)
                                        self.globalProgress = Float(currentFinished) / Float(totalSources)
                                    }
                                }
                            }
                
                // Wait for all concurrent threads to resolve completely
                fetchGroup.wait()
                
                // Check if we captured anything at all, ignoring the timed out sources
                if aggregatedModules.isEmpty {
                    self.updateStep(.failed("Network aggregation returned zero remote modules across all sources due to timeouts."))
                    return
                }
                
                // 3. Payload Selection Processing Stage
                self.updateStep(.processingSelection)
                Thread.sleep(forTimeInterval: 0.6)
                
                let targetCount = min(3, aggregatedModules.count)
                let selectedModules: [String] = aggregatedModules.prefix(targetCount).map { $0.name }
                
                DispatchQueue.main.sync {
                    self.installers = selectedModules.map { name in
                        InstallTracker(moduleName: name, progress: 0.0, status: "Queued")
                    }
                    self.currentStep = .installingModules
                }
                
                // 4. Sequential Module Installation Pipeline (Simulated Driver Loop)
                for i in 0..<targetCount {
                    let moduleName = selectedModules[i]
                    
                    DispatchQueue.main.async {
                        if self.installers.indices.contains(i) {
                            self.installers[i].status = "Installing"
                        }
                    }
                    
                    for progressTick in 1...100 {
                        Thread.sleep(forTimeInterval: 0.025)
                        
                        DispatchQueue.main.async {
                            if self.installers.indices.contains(i) {
                                self.installers[i].progress = Float(progressTick) / 100.0
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        if self.installers.indices.contains(i) {
                            self.installers[i].status = "Completed"
                            self.installers[i].progress = 1.0
                        }
                    }
                }
                
                // 5. Run Execution Finalization Pipeline
                self.updateStep(.finished)
            }
        }
    
    // ─────────────────────────────────────────────────────────────────────────
    //  EXPLICIT MODULE ACTIONS (UI Event Hooks Utilizing Target Engine Tasks)
    // ─────────────────────────────────────────────────────────────────────────
    func installModule(engine: XBibleEngine, source: String, moduleName: String, skipDatabase: Bool = false) {
        queue.async { [weak self] in
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
            
            // Trigger asynchronous layout processing and securely capture the identifier token
            let taskId = engine.installModuleAsync(source: source, moduleName: moduleName)
            self.activeInstallTasks[moduleName] = taskId
            
            // Keep background worker context sequentially contained without spinning a dynamic timer loop
            // Keep background worker context sequentially contained without spinning a dynamic timer loop
            while let status = engine.getTaskStatus(taskId: taskId), status.state == .running {
                // Safely update specific intermediate stream metrics
                let progressValue = status.progress
                
                DispatchQueue.main.async {
                    // Passing 0 for bytes if your TaskStatus doesn't expose them directly,
                    // or swap them with your exact property names.
                    self.messages.send(.installProgress(
                        moduleName: moduleName,
                        progress: progressValue,
                        status: "Downloading",
                        downloadedBytes: 0,
                        totalBytes: 0
                    ))
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // Pop item context from tracking dictionary once transaction lifecycle finishes running
            self.activeInstallTasks.removeValue(forKey: moduleName)
            let isSuccess = engine.isModuleInstalled(moduleName: moduleName)
            
            DispatchQueue.main.async {
                if isSuccess {
                    if !skipDatabase { self.removePendingInstallation(moduleName: moduleName) }
                    self.messages.send(.installCompleted(moduleName: moduleName))
                } else {
                    self.messages.send(.installFailed(moduleName: moduleName))
                }
            }
        }
    }
    
    func refreshInstalledModules(completion: @escaping ([XbibleEngine.SwordModule]) -> Void) {
        queue.async { [weak self] in
            guard let self = self, let engine = self.engine else { return }
            let modules = engine.refreshInstalledModules()
            DispatchQueue.main.async {
                completion(modules)
            }
        }
    }
    
    func cancelInstallation(moduleName: String) {
        guard let engine = self.engine else { return }
        queue.async {
            // Locate precise token identifier from dictionary stack frame context
            if let taskId = self.activeInstallTasks[moduleName] {
                engine.cancelTask(taskId: taskId)
                self.activeInstallTasks.removeValue(forKey: moduleName)
            }
            
            DispatchQueue.main.async {
                self.removePendingInstallation(moduleName: moduleName)
                self.messages.send(.installCancelled(moduleName: moduleName))
            }
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    //  STATE UPDATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────
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
