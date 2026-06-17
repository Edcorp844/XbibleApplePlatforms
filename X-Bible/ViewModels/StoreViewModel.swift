import SwiftUI
import XbibleEngine
import Combine
import SwiftData

@MainActor
class StoreViewModel: ObservableObject {

    // MARK: - Published

    /// Modules grouped by source: [SourceName: [Modules]]
    @Published var allRemoteModules: [String: [XbibleEngine.SwordModule]] = [:]
    /// List of available repositories (CrossWire, IBT, etc.)
    @Published var availableSources: [XbibleEngine.ModuleSource] = []
    /// Tracking the status of every module (idle, installing, installed)
    @Published var installationStates: [String: InstallationStatus] = [:]
    /// Global loading state for the catalog
    @Published var isLoading = false
    /// Search filter string
    @Published var searchText: String = ""
    
    // MARK: - Pipeline State Mirrors
    @Published var currentPipelineStep: EngineStep = .initializing
    @Published var globalSyncProgress: Float = 0.0

    // MARK: - Private

    private var taskManager: StoreTaskManager?
    private var cancellables = Set<AnyCancellable>()
    private var engine: XBibleEngine?
    private var modelContext: ModelContext?

    // MARK: - Computed Properties

    /// Groups all modules across all sources into [Category: [Language: [Modules]]] safely
    var organizedModules: [String: [String: [XbibleEngine.SwordModule]]] {
        // Collect modules using stable array references to prevent intermediate state flickers
        let allModules = allRemoteModules.values.flatMap { $0 }

        if allModules.isEmpty { return [:] }

        let filtered: [XbibleEngine.SwordModule] = searchText.isEmpty ? allModules : allModules.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }

        let byCategory = Dictionary(grouping: filtered, by: { $0.category })
        return byCategory.mapValues { modules in
            Dictionary(grouping: modules, by: { $0.language })
        }
    }

    // MARK: - Setup

    func setup(modelContext: SwiftData.ModelContext, wrapper: SwordEngineWrapper) {
        guard self.engine == nil else {
            syncAllInstallationStatuses()
            return
        }

        self.modelContext = modelContext
        self.engine = wrapper.engine
        self.taskManager = wrapper.storeTaskManager

        setupMessageListeners()
        setupPipelineBindings()
        
        if let engine = self.engine {
            taskManager?.setup(modelContext: modelContext, engine: engine, queue: wrapper.engineQueue)
        }
    }

    private func setupMessageListeners() {
        taskManager?.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleTaskMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func setupPipelineBindings() {
        guard let manager = taskManager else { return }
        
        manager.$currentStep
            .receive(on: DispatchQueue.main)
            .sink { [weak self] step in
                guard let self = self else { return }
                self.currentPipelineStep = step
                
                switch step {
                case .initializing, .fetchingSources:
                    // Keep view operational rather than blocking view state actions entirely
                    self.isLoading = self.allRemoteModules.isEmpty
                case .processingSelection, .installingModules, .failed, .finished:
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
            
        manager.$globalProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.globalSyncProgress = progress
            }
            .store(in: &cancellables)
    }

    // MARK: - Message Handling

    private func handleTaskMessage(_ message: TaskMessage) {
        switch message {
        case .sourcesUpdated(let sources):
            self.availableSources = sources

        case .fetchCompleted(let source, let modules):
            // Injecting modules dynamically updates the specific category arrays without stalling background queues
            self.allRemoteModules[source] = modules
            self.syncAllInstallationStatuses()

        case .installProgress(let moduleName, let progress, let status, let downloaded, let total):
            let details = ModuleDownloadDetails(
                progress: progress,
                status: status,
                downloadedBytes: downloaded,
                totalBytes: total
            )
            self.installationStates[moduleName] = .installing(details: details)

        case .installCompleted(let moduleName):
            self.installationStates[moduleName] = .installed
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)

        case .installFailed(let moduleName), .installCancelled(let moduleName):
            self.installationStates[moduleName] = .idle
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)
            
        case .fetchFailed(let source):
            print("Failed to fetch modules for source: \(source)")

        default:
            break
        }
    }

    // MARK: - Actions

    func loadStore(wrapper: SwordEngineWrapper) {
        guard let _ = wrapper.engine else { return }
        if self.allRemoteModules.isEmpty { self.isLoading = true }
        taskManager?.startSynchronizationPipeline()
    }

    func refreshStore() {
        allRemoteModules.removeAll()
        isLoading = true
        taskManager?.startSynchronizationPipeline()
    }

    func install(module: XbibleEngine.SwordModule, wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.engine, let taskManager = taskManager else { return }
        
        // Retain dynamic interactions immediately so users aren't locked out during live indexing
        installationStates[module.name] = .pending
        taskManager.installModule(engine: engine, source: module.source, moduleName: module.name, skipDatabase: false)
    }

    func cancelInstall(moduleName: String) {
        taskManager?.cancelInstallation(moduleName: moduleName)
        installationStates[moduleName] = .idle
    }

    func syncAllInstallationStatuses() {
        guard let taskManager = taskManager else { return }
        
        taskManager.refreshInstalledModules { [weak self] (installedModules: [XbibleEngine.SwordModule]) in
            guard let self = self else { return }
            
            let installedNames = Set(installedModules.map { $0.name })
            let remoteModules = self.allRemoteModules.values.flatMap { $0 }
            
            for module in remoteModules {
                if installedNames.contains(module.name) {
                    if self.installationStates[module.name] != .installed {
                        self.installationStates[module.name] = .installed
                    }
                } else {
                    let currentState = self.installationStates[module.name]
                    if case .installing = currentState { continue }
                    if currentState == .pending { continue }
                    
                    if self.installationStates[module.name] != .idle {
                        self.installationStates[module.name] = .idle
                    }
                }
            }
        }
    }
}
