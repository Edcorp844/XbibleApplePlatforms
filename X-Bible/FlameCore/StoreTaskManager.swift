import Foundation
import XbibleEngine
import Combine
import SwiftData

// MARK: - Pipeline Step

enum EngineStep: Equatable {
    case initializing
    case fetchingSource(name: String)
    case processingSelection
    case installingModules
    case failed(String)
    case finished
}

// MARK: - Install Tracker

struct InstallTracker: Identifiable {
    let id = UUID()
    let moduleName: String
    var progress: Float
    var status: String
}

// MARK: - Store Task Manager

class StoreTaskManager: ObservableObject {
    @Published var currentStep: EngineStep = .initializing
    @Published var installers: [InstallTracker] = []
    @Published var globalProgress: Float = 0.0

    let messages = PassthroughSubject<TaskMessage, Never>()

    // 📂 CHANNEL 1: Low-priority background sync lane
    private var catalogSyncQueue = DispatchQueue(label: "com.xbible.catalog-sync-queue", qos: .background)

    // ⚡️ CHANNEL 2: Ultra-high-priority execution lane for instant user feedback
    private var userInteractionQueue = DispatchQueue(label: "com.xbible.user-interaction-queue", qos: .userInteractive)

    private var modelContext: ModelContext?
    private var engine: XBibleEngine?

    private var activeInstallTasks: [String: String] = [:] // [ModuleName: TaskId]
    private let activeTasksLock = NSRecursiveLock()

    // Generation token so switching sources rapidly cancels stale fetches.
    private var fetchGeneration: Int = 0
    private let generationLock = NSLock()

    // MARK: - Setup

    func setup(modelContext: ModelContext, engine: XBibleEngine, queue: DispatchQueue? = nil) {
        self.modelContext = modelContext
        self.engine = engine

        // On first open, only fetch the list of sources — not every catalog.
        startSynchronizationPipelineForSourceListOnly()
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  CHANNEL 1: CATALOG SYNCHRONIZATION (Low Priority Background Execution)
    // ─────────────────────────────────────────────────────────────────────────

    /// Fetch only the catalog for a single, user-selected source.
    func startSynchronizationPipeline(for source: ModuleSource) {
        guard let engine = self.engine else { return }

        // Bump the generation so any in-flight fetch for a previous source
        // discards its results when it returns.
        generationLock.lock()
        fetchGeneration += 1
        let generation = fetchGeneration
        generationLock.unlock()

        catalogSyncQueue.async { [weak self] in
            guard let self = self else { return }

            let sourceIdentifier = "\(source.name)"

            self.updateStep(.fetchingSource(name: sourceIdentifier))
            DispatchQueue.main.async { self.globalProgress = 0.0 }

            print("📡 Syncing repository: \(sourceIdentifier)...")

            let modules = engine.fetchRemoteModules(sourceName: sourceIdentifier)

            // Bail if the user has since switched to a different source.
            self.generationLock.lock()
            let stillCurrent = (generation == self.fetchGeneration)
            self.generationLock.unlock()
            guard stillCurrent else {
                print("↩️ Discarding stale fetch for \(sourceIdentifier) (generation \(generation))")
                return
            }

            DispatchQueue.main.async {
                if modules.isEmpty {
                    self.messages.send(.fetchFailed(source: sourceIdentifier))
                    self.updateStep(.failed("No modules returned for \(sourceIdentifier)."))
                } else {
                    self.messages.send(.fetchCompleted(source: sourceIdentifier, modules: modules))
                    self.globalProgress = 1.0
                    self.updateStep(.finished)
                }
            }
        }
    }

    /// Fetch just the list of available sources — no module catalogs.
    /// Used on first open when no source has been selected yet.
    func startSynchronizationPipelineForSourceListOnly() {
        guard let engine = self.engine else { return }

        catalogSyncQueue.async { [weak self] in
            guard let self = self else { return }

            self.updateStep(.initializing)

            let sources = engine.getRemoteSourcesWithDetails()
            if sources.isEmpty {
                self.updateStep(.failed("No remote sources configured."))
                return
            }

            DispatchQueue.main.async {
                self.messages.send(.sourcesUpdated(sources))
                self.updateStep(.finished)
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

            // ⏳ If the catalog for this same source is still being fetched,
            // wait for it to finish before kicking off the install. This avoids
            // the C++ layer fighting itself over the same module directory.
            if case .fetchingSource(let activeSource) = self.currentStep, activeSource == source {
                print("⏳ Source \(source) is currently syncing. Postponing installation start...")
                var retryCount = 0
                while case .fetchingSource(let activeSource) = self.currentStep,
                      activeSource == source,
                      retryCount < 20 {
                    Thread.sleep(forTimeInterval: 0.2)
                    retryCount += 1
                }
            }

            // 🛠️ Force the C++ layer to refresh its internal target install
            // directory pointer. Binds a writable path context before extraction.
            print("🔧 Initializing target directory permissions for \(moduleName)...")
            _ = engine.refreshInstalledModules()

            // Now fire the extraction task safely.
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
                    print("🚨 Extraction pipeline failed. Check file path sandbox limits.")
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

    // MARK: - Helpers

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
