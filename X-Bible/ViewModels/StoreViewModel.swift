import SwiftUI
import XbibleEngine
import Combine
import SwiftData

@MainActor
class StoreViewModel: ObservableObject {

    // MARK: - Published

    /// Modules for the currently-selected source only.
    @Published var modulesForCurrentSource: [XbibleEngine.SwordModule] = []

    /// List of available repositories (CrossWire, IBT, etc.) for the source picker.
    @Published var availableSources: [XbibleEngine.ModuleSource] = []

    /// The one source whose catalog is currently loaded into the UI.
    @Published var currentSource: XbibleEngine.ModuleSource?

    /// Tracking the status of every module (idle, installing, installed).
    /// Keyed by module name so it survives source switches.
    @Published var installationStates: [String: InstallationStatus] = [:]

    /// Loading state for the *current* source's catalog fetch.
    @Published var isLoading = false

    /// Search filter string.
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

    /// Groups the current source's modules into [Category: [Language: [Modules]]].
    var organizedModules: [String: [String: [XbibleEngine.SwordModule]]] {
        let allModules = modulesForCurrentSource
        if allModules.isEmpty { return [:] }

        let filtered: [XbibleEngine.SwordModule] = searchText.isEmpty
            ? allModules
            : allModules.filter {
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
                case .initializing, .fetchingSource:
                    self.isLoading = self.modulesForCurrentSource.isEmpty
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
            // If nothing selected yet, default to the first source.
            if self.currentSource == nil, let first = sources.first {
                self.selectSource(first, wrapper: nil)
            }

        case .fetchCompleted(let source, let modules):
            // Only accept the fetch if it's for the source we currently care about.
            // This prevents a late-arriving fetch from a source the user already
            // switched away from clobbering the UI.
            guard let current = self.currentSource,
                  current.name == source else {
                return
            }
            self.modulesForCurrentSource = modules
            self.isLoading = false
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
            // Clear loading if the source that failed is the one we're waiting on.
            if let current = self.currentSource,
               current.name == source {
                self.isLoading = false
                self.modulesForCurrentSource = []
            }
            print("Failed to fetch modules for source: \(source)")

        default:
            break
        }
    }

    // MARK: - Source Selection

    /// Switches the active source and fetches only that source's catalog.
    /// Passing `wrapper: nil` uses the previously stored taskManager (for the
    /// initial auto-select in `sourcesUpdated`).
    func selectSource(_ source: XbibleEngine.ModuleSource, wrapper: SwordEngineWrapper?) {
        guard currentSource?.name != source.name else { return }

        currentSource = source
        modulesForCurrentSource = []
        isLoading = true

        // Kick off a fetch for just this source.
        taskManager?.startSynchronizationPipeline(for: source)
    }

    // MARK: - Actions

    func loadStore(wrapper: SwordEngineWrapper) {
        guard wrapper.engine != nil else { return }

        // If we already have a source, load only that one.
        // Otherwise, kick the pipeline to populate the source list first;
        // the `.sourcesUpdated` handler will auto-select and fetch.
        if let current = currentSource {
            modulesForCurrentSource = []
            isLoading = true
            taskManager?.startSynchronizationPipeline(for: current)
        } else {
            isLoading = true
            taskManager?.startSynchronizationPipelineForSourceListOnly()
        }
    }

    func refreshStore() {
        guard let current = currentSource else { return }
        modulesForCurrentSource = []
        isLoading = true
        taskManager?.startSynchronizationPipeline(for: current)
    }

    func install(module: XbibleEngine.SwordModule, wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.engine, let taskManager = taskManager else { return }

        installationStates[module.name] = .pending
        taskManager.installModule(
            engine: engine,
            source: module.source,
            moduleName: module.name,
            skipDatabase: false
        )
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
            let remoteModules = self.modulesForCurrentSource

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
