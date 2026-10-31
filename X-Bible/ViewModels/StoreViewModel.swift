import SwiftUI
import XbibleEngine
import Combine
import SwiftData

@MainActor
final class StoreViewModel: ObservableObject {

    // MARK: - Published (raw state)

    @Published var modulesForCurrentSource: [XbibleEngine.SwordModule] = []
    @Published var availableSources: [XbibleEngine.ModuleSource] = []
    @Published var currentSource: XbibleEngine.ModuleSource?
    @Published var installationStates: [String: InstallationStatus] = [:]
    @Published var isLoading = false
    @Published var searchText: String = ""
    @Published var currentPipelineStep: EngineStep = .initializing
    @Published var globalSyncProgress: Float = 0.0

    // MARK: - Published (derived, view-facing)

    /// Categories for the tab bar: `["All"] + sorted categories`.
    @Published private(set) var availableCategories: [String] = ["All"]

    /// The modules grouped by language, already filtered by the current
    /// category and by `searchText`. The view reads ONLY this.
    @Published private(set) var filteredLanguages: [String: [XbibleEngine.SwordModule]] = [:]

    /// Pre-computed, per-module installation status the view binds to.
    /// Matches `installationStates`, but the view doesn't need to look up
    /// keys — it reads `status(for:)` which reads from this snapshot.
    @Published private(set) var visibleStatuses: [String: InstallationStatus] = [:]

    // MARK: - Selected category (moved from view)

    /// Owned here so the view-model can recompute `filteredLanguages`
    /// whenever the category changes.
    @Published var selectedCategory: String = "All"

    // MARK: - Private

    private var taskManager: StoreTaskManager?
    private var cancellables = Set<AnyCancellable>()
    private var engine: XBibleEngine?
    private var modelContext: ModelContext?

    init() {
        // Recompute derived state whenever any of the inputs change.
        // All republishes go through `DispatchQueue.main.async` so we
        // never publish mid-render.
        Publishers.Merge3(
            $modulesForCurrentSource.map { _ in () }.eraseToAnyPublisher(),
            $installationStates.map { _ in () }.eraseToAnyPublisher(),
            $selectedCategory.map { _ in () }.eraseToAnyPublisher()
        )
        .merge(with: $searchText.map { _ in () }.eraseToAnyPublisher())
        .debounce(for: .milliseconds(30), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.recomputeDerived()
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Public read API for the view

    func status(for module: XbibleEngine.SwordModule) -> InstallationStatus {
        visibleStatuses[module.name] ?? .idle
    }

    // MARK: - Setup

    func setup(modelContext: ModelContext, wrapper: SwordEngineWrapper) {
        guard engine == nil else {
            syncAllInstallationStatuses()
            return
        }

        self.modelContext = modelContext
        self.engine = wrapper.engine
        self.taskManager = wrapper.storeTaskManager

        setupMessageListeners()
        setupPipelineBindings()

        if let engine {
            taskManager?.setup(
                modelContext: modelContext,
                engine: engine,
                queue: wrapper.engineQueue
            )
        }
    }

    private func setupMessageListeners() {
        taskManager?.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.handleTaskMessage(message)
                }
            }
            .store(in: &cancellables)
    }

    private func setupPipelineBindings() {
        guard let manager = taskManager else { return }

        manager.$currentStep
            .receive(on: DispatchQueue.main)
            .sink { [weak self] step in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.currentPipelineStep = step
                    switch step {
                    case .initializing, .fetchingSource:
                        self.isLoading = self.modulesForCurrentSource.isEmpty
                    case .processingSelection, .installingModules, .failed, .finished:
                        self.isLoading = false
                    }
                }
            }
            .store(in: &cancellables)

        manager.$globalProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.globalSyncProgress = progress
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Message handling

    private func handleTaskMessage(_ message: TaskMessage) {
        switch message {
        case .sourcesUpdated(let sources):
            availableSources = sources
            if currentSource == nil, let first = sources.first {
                selectSource(first, wrapper: nil)
            }

        case .fetchCompleted(let source, let modules):
            guard let current = currentSource, current.name == source else { return }
            modulesForCurrentSource = modules
            isLoading = false
            syncAllInstallationStatuses()

        case .installProgress(let moduleName, let progress, let status, let downloaded, let total):
            let details = ModuleDownloadDetails(
                progress: progress,
                status: status,
                downloadedBytes: downloaded,
                totalBytes: total
            )
            installationStates[moduleName] = .installing(details: details)

        case .installCompleted(let moduleName):
            installationStates[moduleName] = .installed
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)

        case .installFailed(let moduleName), .installCancelled(let moduleName):
            installationStates[moduleName] = .idle
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)

        case .fetchFailed(let source):
            if let current = currentSource, current.name == source {
                isLoading = false
                modulesForCurrentSource = []
            }
            print("Failed to fetch modules for source: \(source)")

        default:
            break
        }
    }

    // MARK: - Source selection

    func selectSource(_ source: XbibleEngine.ModuleSource, wrapper: SwordEngineWrapper?) {
        guard currentSource?.name != source.name else { return }
        currentSource = source
        modulesForCurrentSource = []
        isLoading = true
        taskManager?.startSynchronizationPipeline(for: source)
    }

    // MARK: - Actions

    func loadStore(wrapper: SwordEngineWrapper) {
        guard wrapper.engine != nil else { return }
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
        guard let engine = wrapper.engine, let taskManager else { return }
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

    func setCategory(_ category: String) {
        guard selectedCategory != category else { return }
        selectedCategory = category
    }

    // MARK: - Installation status sync

    func syncAllInstallationStatuses() {
        guard let taskManager else { return }
        taskManager.refreshInstalledModules { [weak self] installedModules in
            guard let self else { return }
            let installedNames = Set(installedModules.map(\.name))
            let remoteModules = self.modulesForCurrentSource

            DispatchQueue.main.async {
                for module in remoteModules {
                    if installedNames.contains(module.name) {
                        if self.installationStates[module.name] != .installed {
                            self.installationStates[module.name] = .installed
                        }
                    } else {
                        if case .installing = self.installationStates[module.name] { continue }
                        if self.installationStates[module.name] == .pending { continue }
                        if self.installationStates[module.name] != .idle {
                            self.installationStates[module.name] = .idle
                        }
                    }
                }
            }
        }
    }

    // MARK: - Derived state (only place these run)

    /// Rebuilds `availableCategories`, `filteredLanguages`, and `visibleStatuses`
    /// from the current raw state. Called from a Combine sink on the main queue
    /// after a debounce, so it can never run mid-render.
    private func recomputeDerived() {
        // 1) availableCategories
        let categories = Set(modulesForCurrentSource.map(\.category))
        let sortedCategories = ["All"] + categories.sorted()

        // Ensure selectedCategory is valid.
        let effectiveCategory: String
        if sortedCategories.contains(selectedCategory) {
            effectiveCategory = selectedCategory
        } else {
            effectiveCategory = "All"
            selectedCategory = "All"
        }

        // 2) Base modules filtered by category
        let baseModules: [XbibleEngine.SwordModule]
        if effectiveCategory == "All" {
            baseModules = modulesForCurrentSource
        } else {
            baseModules = modulesForCurrentSource.filter { $0.category == effectiveCategory }
        }

        // 3) Apply search filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let searchedModules: [XbibleEngine.SwordModule]
        if query.isEmpty {
            searchedModules = baseModules
        } else {
            searchedModules = baseModules.filter { matches($0, query: query) }
        }

        // 4) Group by language
        let grouped = Dictionary(grouping: searchedModules, by: \.language)

        // 5) visibleStatuses snapshot
        var statuses: [String: InstallationStatus] = [:]
        statuses.reserveCapacity(searchedModules.count)
        for m in searchedModules {
            statuses[m.name] = installationStates[m.name] ?? .idle
        }

        // Assign all at once. Each assignment is `@Published`, but we're on
        // a post-render tick so SwiftUI won't complain.
        availableCategories = sortedCategories
        filteredLanguages = grouped
        visibleStatuses = statuses
    }

    private func matches(_ module: XbibleEngine.SwordModule, query: String) -> Bool {
        if module.name.lowercased().contains(query) { return true }
        if module.description.lowercased().contains(query) { return true }
        if module.category.lowercased().contains(query) { return true }
        if module.language.lowercased().contains(query) { return true }
        if module.source.lowercased().contains(query) { return true }
        if module.version.lowercased().contains(query) { return true }
        if module.delta.lowercased().contains(query) { return true }
        if module.features.contains(where: { $0.lowercased().contains(query) }) { return true }
        return false
    }
}
