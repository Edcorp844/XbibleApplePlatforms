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

    // MARK: - Private

    private var taskManager: StoreTaskManager?
    private var cancellables = Set<AnyCancellable>()
    private var engine: BibleEngine?
    private var modelContext: ModelContext?

    // MARK: - Computed Properties

    /// Groups all modules across all sources into [Category: [Language: [Modules]]] for the UI
    var organizedModules: [String: [String: [XbibleEngine.SwordModule]]] {
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
        // Prevent double setup if navigating back and forth
        guard self.engine == nil else {
            syncAllInstallationStatuses()
            return
        }

        self.modelContext = modelContext
        self.engine = wrapper.engine
        self.taskManager = wrapper.storeTaskManager

        setupMessageListeners()
        
        // Ensure the task manager is initialized with the engine and context
        if let engine = self.engine {
            taskManager?.setup(modelContext: modelContext, engine: engine, queue: wrapper.engineQueue)
        }
        
        loadStore(wrapper: wrapper)
    }

    private func setupMessageListeners() {
        taskManager?.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleTaskMessage(message)
            }
            .store(in: &cancellables)
    }

    // MARK: - Message Handling

    private func handleTaskMessage(_ message: TaskMessage) {
        switch message {
        case .sourcesUpdated(let sources):
            self.availableSources = sources
            self.fetchAllSources()

        case .fetchCompleted(let source, let modules):
            self.allRemoteModules[source] = modules
            // Stop loading once we have data from all sources
            if allRemoteModules.keys.count >= availableSources.count {
                self.isLoading = false
            }
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
            // Notify other parts of the app that the library has changed
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)

        case .installFailed(let moduleName), .installCancelled(let moduleName):
            self.installationStates[moduleName] = .idle
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)
            
        case .fetchFailed(let source):
            print("Failed to fetch modules for source: \(source)")
            // Potentially increment count anyway to stop the spinner
            if allRemoteModules.keys.count >= availableSources.count { self.isLoading = false }

        default:
            break
        }
    }

    // MARK: - Actions

    /// Initial fetch of the repository list
    func loadStore(wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.engine else { return }
        self.isLoading = true
        taskManager?.fetchSources(engine: engine)
    }

    /// Triggers a fresh download of the module catalogs
    func refreshStore() {
        guard let engine = engine else { return }
        allRemoteModules.removeAll()
        isLoading = true
        taskManager?.fetchSources(engine: engine)
    }

    /// Installs a module using the background engine to avoid UI hangs
    func install(module: XbibleEngine.SwordModule, wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.engine, let taskManager = taskManager else { return }
        
        // UI feedback: immediately mark as pending
        installationStates[module.name] = .pending
        taskManager.installModule(engine: engine, source: module.source, moduleName: module.name)
    }

    /// Stops an active download/installation
    func cancelInstall(moduleName: String) {
        taskManager?.cancelInstallation(moduleName: moduleName)
        installationStates[moduleName] = .idle
    }

    /// Batch check against the disk to see what is already installed
    func syncAllInstallationStatuses() {
        guard let taskManager = taskManager else { return }
        
        taskManager.refreshInstalledModules { [weak self] installedModules in
            guard let self = self else { return }
            
            let installedNames = Set(installedModules.map { $0.name })
            let remoteModules = self.allRemoteModules.values.flatMap { $0 }
            
            for module in remoteModules {
                if installedNames.contains(module.name) {
                    if self.installationStates[module.name] != .installed {
                        self.installationStates[module.name] = .installed
                    }
                } else {
                    // If not installed, only reset to idle if we aren't currently installing it or pending
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

    // MARK: - Private Helpers

    private func fetchAllSources() {
        guard let engine = engine, let taskManager = taskManager else { return }
        
        if availableSources.isEmpty {
            self.isLoading = false
            return
        }

        for source in availableSources {
            // isSilent: true keeps the UI from flickering while multiple sources load
            taskManager.fetchModules(engine: engine, source: source.name, isSilent: true)
        }
    }
}
