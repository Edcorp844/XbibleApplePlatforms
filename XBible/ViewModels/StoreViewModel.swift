//
//  StoreViewModel.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine
import Combine


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
    
    init() {
        setupMessageListeners()
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
            
            // Update installation states
            for m in modules {
                if installationStates[m.name] == nil {
                    installationStates[m.name] = .idle
                }
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
            
        case .installFailed(let moduleName):
            installationStates[moduleName] = .idle
            
        case .installCancelled(let moduleName):
            installationStates[moduleName] = .idle
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

    func install(module: SwordModule, wrapper: SwordEngineWrapper) {
        guard let engine = wrapper.engine else { return }
        let moduleName = module.name
        
        if installationStates[moduleName] == .installed { return }
        
        taskManager.installModule(engine: engine, source: selectedSource, moduleName: moduleName)
    }

    func cancelInstallation(moduleName: String) {
        taskManager.cancelInstallation(moduleName: moduleName)
    }
}
