import Foundation
import XbibleEngine
import Combine
import SwiftData



class StoreTaskManager: ObservableObject {
    let messages = PassthroughSubject<TaskMessage, Never>()
    
    private var queue = DispatchQueue(label: "com.xbible.store-task-manager", qos: .userInitiated)
    private let pollQueue = DispatchQueue(label: "com.xbible.store-task-manager.poll", qos: .utility)
    
    private var modelContext: ModelContext?
    private var engine: BibleEngine? // Stored for easier access
    
    private var activeTasks: [String: ActiveTask] = [:]
    private var pollTimer: DispatchSourceTimer?
    
    private var fetchingSources = Set<String>()
    private var cachedModules: [String: [XbibleEngine.SwordModule]] = [:]
    private var cachedSources: [XbibleEngine.ModuleSource]?
    
    struct ActiveTask {
        let moduleName: String
        let source: String
        let type: TaskType
    }
    
    enum TaskType {
        case fetchModules
        case installModule
    }
    
    func setup(modelContext: ModelContext, engine: BibleEngine, queue: DispatchQueue? = nil) {
        if let sharedQueue = queue {
            self.queue = sharedQueue
        }
        self.modelContext = modelContext
        self.engine = engine
        resumePendingInstallations()
        startPolling()
    }
    
    private func startPolling() {
        guard let engine = self.engine else { return }
        pollTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now(), repeating: 0.4)
        timer.setEventHandler { [weak self] in
            self?.pollActiveTasks(engine: engine)
        }
        timer.resume()
        self.pollTimer = timer
    }
    
    func fetchSources(engine: BibleEngine) {
        if let cached = cachedSources {
            messages.send(.sourcesUpdated(cached))
            return
        }
        
        queue.async { [weak self] in
            let sources = engine.getRemoteSourcesWithDetails()
            self?.cachedSources = sources
            DispatchQueue.main.async {
                if sources.isEmpty {
                    self?.messages.send(.sourcesFailed)
                } else {
                    self?.messages.send(.sourcesUpdated(sources))
                }
            }
        }
    }
    
    func fetchModules(engine: BibleEngine, source: String, isSilent: Bool = false) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.fetchingSources.contains(source) { return }
            
            if let cached = self.cachedModules[source] {
                DispatchQueue.main.async {
                    self.messages.send(.fetchCompleted(source: source, modules: cached))
                }
                return
            }
            
            self.fetchingSources.insert(source)
            DispatchQueue.main.async {
                if !isSilent { self.messages.send(.fetchStarted) }
            }
            
            let taskId = engine.fetchModulesAsync(sourceName: source)
            self.activeTasks[taskId] = ActiveTask(moduleName: "", source: source, type: .fetchModules)
        }
    }
    
    func getCachedModules(source: String) -> [XbibleEngine.SwordModule]? {
        // This is a bit tricky if we want total thread safety, but for now we'll return what we have
        return queue.sync { cachedModules[source] }
    }
    
    func refreshModules(engine: BibleEngine, source: String) {
        queue.async { [weak self] in
            self?.cachedModules.removeValue(forKey: source)
            self?.fetchModules(engine: engine, source: source)
        }
    }
    
    func installModule(engine: BibleEngine, source: String, moduleName: String, skipDatabase: Bool = false) {
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
            
            let taskId = engine.installModuleAsync(source: source, moduleName: moduleName)
            self.activeTasks[taskId] = ActiveTask(moduleName: moduleName, source: source, type: .installModule)
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
            if let taskId = self.activeTasks.first(where: { $0.value.moduleName == moduleName })?.key {
                engine.cancelTask(taskId: taskId)
                self.activeTasks.removeValue(forKey: taskId)
            }
            DispatchQueue.main.async {
                self.removePendingInstallation(moduleName: moduleName)
                self.messages.send(.installCancelled(moduleName: moduleName))
            }
        }
    }
    
    private func pollActiveTasks(engine: BibleEngine) {
        // Only poll if we actually have tasks to avoid constant FFI noise
        guard !activeTasks.isEmpty else { return }

        // Execute polling on the serialized serial queue, NOT the concurrent pollQueue
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let tasksToPoll = self.activeTasks
            for (taskId, taskInfo) in tasksToPoll {
                if let status = self.engine?.getTaskStatus(taskId: taskId) {
                    switch status.state {
                    case .running:
                        self.notifyProgress(taskInfo: taskInfo, status: status)
                    case .completed:
                        self.handleSuccess(taskId: taskId, taskInfo: taskInfo)
                    case .failed(let error):
                        self.handleFailure(taskId: taskId, taskInfo: taskInfo, error: error)
                    default: break
                    }
                }
            }
        }
    }
    
    private func notifyProgress(taskInfo: ActiveTask, status: TaskStatus) {
        DispatchQueue.main.async {
            switch taskInfo.type {
            case .fetchModules:
                self.messages.send(.fetchProgress(progress: status.progress, status: "Updating catalog...", downloadedBytes: 0, totalBytes: 0))
            case .installModule:
                self.messages.send(.installProgress(moduleName: taskInfo.moduleName, progress: status.progress, status: status.message, downloadedBytes: 0, totalBytes: 0))
            }
        }
    }
    
    private func handleSuccess(taskId: String, taskInfo: ActiveTask) {
        // Already on queue.async from pollActiveTasks
        self.activeTasks.removeValue(forKey: taskId)
        
        if taskInfo.type == .fetchModules {
            let modules = self.engine?.getTaskResultModules(taskId: taskId) ?? []
            self.cachedModules[taskInfo.source] = modules
            self.fetchingSources.remove(taskInfo.source)
            
            DispatchQueue.main.async {
                self.messages.send(.fetchCompleted(source: taskInfo.source, modules: modules))
            }
        } else {
            DispatchQueue.main.async {
                self.removePendingInstallation(moduleName: taskInfo.moduleName)
                self.messages.send(.installCompleted(moduleName: taskInfo.moduleName))
            }
        }
    }
    
    private func handleFailure(taskId: String, taskInfo: ActiveTask, error: String) {
        // Already on queue.async from pollActiveTasks
        self.activeTasks.removeValue(forKey: taskId)
        
        if taskInfo.type == .fetchModules {
            self.fetchingSources.remove(taskInfo.source)
            DispatchQueue.main.async {
                self.messages.send(.fetchFailed(source: taskInfo.source))
            }
        } else {
            DispatchQueue.main.async {
                if error.contains("Cancelled") {
                    self.messages.send(.installCancelled(moduleName: taskInfo.moduleName))
                } else {
                    self.messages.send(.installFailed(moduleName: taskInfo.moduleName))
                }
                self.removePendingInstallation(moduleName: taskInfo.moduleName)
            }
        }
    }
    
    private func resumePendingInstallations() {
        guard let engine = engine, let context = modelContext else { return }
        let descriptor = FetchDescriptor<PendingInstallation>(sortBy: [SortDescriptor(\.addedAt)])
        if let pending = try? context.fetch(descriptor) {
            for item in pending { 
                // skipDatabase: true because it's already in the DB
                self.installModule(engine: engine, source: item.source, moduleName: item.moduleName, skipDatabase: true) 
            }
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
