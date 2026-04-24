//
//  StoreViewModel.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine
import Combine
import SwiftData


class StoreViewModel: ObservableObject {
    @Published var remoteModules: [XbibleEngine.SwordModule] = []
    @Published var availableSources: [XbibleEngine.ModuleSource] = []
    @Published var selectedSource: String = "CrossWire"
    @Published var isLoading = false
    @Published var searchText: String = "" {
        didSet {
            if searchText.isEmpty {
                globalSearchResults = [:]
                isSearchingGlobally = false
            }
        }
    }
    
    // Global progress for fetching the catalog
    @Published var globalDownloadDetails: ModuleDownloadDetails?
    
    // Tracking individual module states
    @Published var installationStates: [String: InstallationStatus] = [:]
    
    // Global search results from other sources
    @Published var globalSearchResults: [String: [XbibleEngine.SwordModule]] = [:]
    @Published var isSearchingGlobally = false
    
    private var hasWarmedUp = false
    private var taskManager: StoreTaskManager?
    private var cancellables = Set<AnyCancellable>()
    private var engine: BibleEngine? // The UI management engine
    private var backgroundEngine: BibleEngine? // The heavy task engine
    private var modelContext: ModelContext?
    
    func setup(modelContext: SwiftData.ModelContext, wrapper: SwordEngineWrapper) {
        // Prevent redundant setup if already configured
        if self.taskManager != nil { 
            syncAllInstallationStatuses()
            return 
        }
        
        self.modelContext = modelContext
        
        // Use management engine for quick store operations
        guard let engine = wrapper.managementEngine else { return }
        self.engine = engine
        
        // Use background engine for heavy tasks
        guard let bgEngine = wrapper.backgroundEngine else { return }
        self.backgroundEngine = bgEngine
        
        // Use persistent task manager from wrapper
        self.taskManager = wrapper.storeTaskManager
        setupMessageListeners()
        
        taskManager?.setup(modelContext: modelContext, engine: engine)
        
        // Sync pending installations into the UI dictionary immediately
        let descriptor = SwiftData.FetchDescriptor<PendingInstallation>()
        if let pending = try? modelContext.fetch(descriptor) {
            for item in pending {
                installationStates[item.moduleName] = .pending
            }
        }
        
        // Initial sync
        syncAllInstallationStatuses()
    }
    
    private func setupMessageListeners() {
        guard let taskManager = taskManager else { return }
        
        // Listen for global installation changes (e.g. from LibraryView)
        NotificationCenter.default.publisher(for: .installationStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncAllInstallationStatuses()
            }
            .store(in: &cancellables)
            
        // Listen for all messages from the background task manager on the main thread
        taskManager.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleTaskMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleTaskMessage(_ message: TaskMessage) {
        // All updates happen on main thread - UI is never blocked
        switch message {
        case .sourcesUpdated(let sources):
            availableSources = sources
            // Start warming up all catalogs in the background for instant search
            warmUpAllCatalogs()
            
        case .sourcesFailed:
            availableSources = []
            
        case .fetchStarted:
            isLoading = true
            globalDownloadDetails = nil
            
        case .fetchProgress(let progress, let status, let downloaded, let total):
            globalDownloadDetails = ModuleDownloadDetails(
                progress: progress,
                status: status,
                downloadedBytes: downloaded,
                totalBytes: total
            )
            
        case .fetchCompleted(let source, let modules):
            if source == selectedSource {
                remoteModules = modules
                isLoading = false
                syncAllInstallationStatuses()
            } else {
                handleGlobalSearchFetch(source, modules: modules)
            }
            
        case .fetchFailed:
            isLoading = false
            globalDownloadDetails = nil
            
        case .installStarted(let moduleName):
            installationStates[moduleName] = .pending
            
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
            syncAllInstallationStatuses() // Sync everything else too
            
        case .installFailed(let moduleName):
            installationStates[moduleName] = .idle
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)
            
        case .installCancelled(let moduleName):
            installationStates[moduleName] = .idle
            NotificationCenter.default.post(name: .installationStateChanged, object: nil)
        }
    }
    
    /// Syncs the internal state with the engine's reality for all fetched modules
    func syncAllInstallationStatuses() {
        guard let engine = engine else { return }
        
        // Collect all modules we are currently showing (local + global search results)
        var allShownModules = remoteModules
        for sourceModules in globalSearchResults.values {
            allShownModules.append(contentsOf: sourceModules)
        }
        
        let modules = allShownModules
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var newStates: [String: InstallationStatus] = [:]
            
            for m in modules {
                if engine.isModuleInstalled(moduleName: m.name) {
                    newStates[m.name] = .installed
                }
            }
            
            DispatchQueue.main.async {
                // Merge new states into existing ones (preserve active tasks)
                for (name, status) in newStates {
                    self?.installationStates[name] = status
                }
                
                // For modules not in newStates, if we thought they were installed, set to idle
                // (Only if not currently busy)
                for (name, currentStatus) in self?.installationStates ?? [:] {
                    if currentStatus == .installed && newStates[name] == nil {
                        self?.installationStates[name] = .idle
                    } else if currentStatus == .idle && newStates[name] == nil {
                        // Already idle, keep it
                    }
                }
            }
        }
    }

    var organizedModules: [String: [String: [XbibleEngine.SwordModule]]] {
        let filtered = searchText.isEmpty ? remoteModules : remoteModules.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
        
        let byCategory = Dictionary(grouping: filtered, by: { $0.category })
        return byCategory.mapValues { modules in
            Dictionary(grouping: modules, by: { $0.language })
        }
    }

    func loadStore(wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.managementEngine, let taskManager = taskManager else { return }
        taskManager.fetchSources(engine: engine)
        fetchModules(wrapper: wrapper, source: selectedSource)
    }

    func fetchModules(wrapper: SwordEngineWrapper, source: String) {
        guard let engine = wrapper.managementEngine, let taskManager = taskManager else { return }
        self.selectedSource = source
        // Use management engine for explicit UI-driven fetches
        taskManager.fetchModules(engine: engine, source: source)
    }
    
    func refreshModules(wrapper: SwordEngineWrapper, source: String) {
        guard let engine = wrapper.managementEngine, let taskManager = taskManager else { return }
        self.selectedSource = source
        taskManager.refreshModules(engine: engine, source: source)
    }

    func install(module: XbibleEngine.SwordModule, wrapper: SwordEngineWrapper) {
        guard let bgEngine = wrapper.backgroundEngine, let taskManager = taskManager else { return }
        
        // Update UI state immediately to .pending for instant feedback
        installationStates[module.name] = .pending
        
        // Pass to task manager using the BACKGROUND engine
        taskManager.installModule(engine: bgEngine, source: selectedSource, moduleName: module.name)
    }
    
    func cancelInstall(module: XbibleEngine.SwordModule) {
        taskManager?.cancelInstallation(moduleName: module.name)
    }

    func cancelInstallation(moduleName: String) {
        taskManager?.cancelInstallation(moduleName: moduleName)
    }
    
    func searchAllSources(wrapper: SwordEngineWrapper) {
        guard let bgEngine = wrapper.backgroundEngine, let taskManager = taskManager else { return }
        guard !searchText.isEmpty else { return }
        
        isSearchingGlobally = true
        // Don't clear results entirely, just keep them updating
        // globalSearchResults = [:] 
        
        let otherSources = availableSources.filter { $0.name != selectedSource }
        
        for source in otherSources {
            // Check if we already have it cached from background warming
            if let modules = taskManager.getCachedModules(source: source.name) {
                handleGlobalSearchFetch(source.name, modules: modules)
            }
            
            // Trigger fetch on the BACKGROUND engine
            taskManager.fetchModules(engine: bgEngine, source: source.name, isSilent: true)
        }
    }
    
    private func warmUpAllCatalogs() {
        guard let bgEngine = backgroundEngine, let taskManager = taskManager, !hasWarmedUp else { return }
        hasWarmedUp = true
        
        // Fetch everything silently on the BACKGROUND engine
        let sources = availableSources
        for (index, source) in sources.enumerated() {
            let delay = Double(index) * 0.2 // 200ms between each source
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                taskManager.fetchModules(engine: bgEngine, source: source.name, isSilent: true)
            }
        }
    }
    
    // We need to update handleTaskMessage to handle these multi-source updates
    private func handleGlobalSearchFetch(_ source: String, modules: [XbibleEngine.SwordModule]) {
        let filtered = modules.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
        
        if !filtered.isEmpty {
            globalSearchResults[source] = filtered
        }
        
        // If we've processed all sources (or a reasonable amount), stop the spinner
        // For simplicity, we just keep it updating as they come in
    }
}
