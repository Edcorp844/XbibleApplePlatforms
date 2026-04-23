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
    
    // Global progress for fetching the catalog
    @Published var globalDownloadDetails: ModuleDownloadDetails?
    
    // Tracking individual module states
    @Published var installationStates: [String: InstallationStatus] = [:]
    
    private let taskManager = StoreTaskManager()
    private var cancellables = Set<AnyCancellable>()
    private var engine: BibleEngine?
    private var modelContext: ModelContext?
    
    init() {
        setupMessageListeners()
        
        // Listen for global installation changes (e.g. from LibraryView)
        NotificationCenter.default.publisher(for: .installationStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncAllInstallationStatuses()
            }
            .store(in: &cancellables)
    }
    
    func setup(modelContext: SwiftData.ModelContext, wrapper: SwordEngineWrapper) {
        self.modelContext = modelContext
        guard let engine = wrapper.engine else { return }
        self.engine = engine
        taskManager.setup(modelContext: modelContext, engine: engine)
        
        // Sync pending installations into the UI dictionary immediately
        let descriptor = SwiftData.FetchDescriptor<PendingInstallation>()
        if let pending = try? modelContext.fetch(descriptor) {
            for item in pending {
                installationStates[item.moduleName] = .pending
            }
        }
    }
    
    private func setupMessageListeners() {
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
            
        case .fetchCompleted(let modules):
            remoteModules = modules
            isLoading = false
            syncAllInstallationStatuses()
            
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
        
        // We do this on the main thread but it's fast enough for the store list
        for m in remoteModules {
            if engine.isModuleInstalled(moduleName: m.name) {
                installationStates[m.name] = .installed
            } else if installationStates[m.name] == nil || installationStates[m.name] == .installed {
                // If the engine says no, and we thought yes or nothing, set to idle
                // (Unless it's currently installing/pending)
                if case .installing = installationStates[m.name] {}
                else if case .pending = installationStates[m.name] {}
                else {
                    installationStates[m.name] = .idle
                }
            }
        }
    }

    var organizedModules: [String: [String: [XbibleEngine.SwordModule]]] {
        let byCategory = Dictionary(grouping: remoteModules, by: { $0.category })
        return byCategory.mapValues { modules in
            Dictionary(grouping: modules, by: { $0.language })
        }
    }

    func loadStore(wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.engine else { return }
        taskManager.fetchSources(engine: engine)
        fetchModules(wrapper: wrapper, source: selectedSource)
    }

    func fetchModules(wrapper: SwordEngineWrapper, source: String) {
        guard let engine = wrapper.engine else { return }
        self.selectedSource = source
        taskManager.fetchModules(engine: engine, source: source)
    }
    
    func refreshModules(wrapper: SwordEngineWrapper, source: String) {
        guard let engine = wrapper.engine else { return }
        self.selectedSource = source
        taskManager.refreshModules(engine: engine, source: source)
    }

    func install(module: XbibleEngine.SwordModule, wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.engine else { return }
        
        // Update UI state immediately to .pending for instant feedback
        installationStates[module.name] = .pending
        
        // Pass to task manager - it will handle background installation and already-installed checks
        taskManager.installModule(engine: engine, source: selectedSource, moduleName: module.name)
    }
    
    func cancelInstall(module: XbibleEngine.SwordModule) {
        taskManager.cancelInstallation(moduleName: module.name)
    }

    func cancelInstallation(moduleName: String) {
        taskManager.cancelInstallation(moduleName: moduleName)
    }
}
