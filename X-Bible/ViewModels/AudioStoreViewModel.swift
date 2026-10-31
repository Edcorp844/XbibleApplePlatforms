//
//  AudioStoreViewModel.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine
import Combine

enum ModuleFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case installed = "Installed"
    case notInstalled = "Not Installed"
    case downloading = "Downloading"

    var id: String { rawValue }
}


@MainActor
final class AudioStoreViewModel: ObservableObject {
    
    // ── Catalog (flat modules list) ──
    @Published var availableModules: [RemoteAudioModuleInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // ── Hierarchy (browsable tree) ──
    @Published var languages: [AudioLanguage] = []
    @Published var selectedLanguageID: String? = nil
    @Published var collections: [AudioCollection] = []
    @Published var selectedCollectionID: String? = nil
    @Published var albums: [AudioAlbum] = []
    @Published var selectedAlbumID: String? = nil
    @Published var modulesInAlbum: [RemoteAudioModuleInfo] = []
    
    // ── Contributors (for display) ──
    @Published var narrators: [AudioContributor] = []
    
    // ── Search / filter ──
    @Published var searchText: String = ""
    @Published var selectedFilter: ModuleFilter = .all
    
    // ── Selection ──
    @Published var selectedModuleID: String? = nil
    
    private let storeService = StoreApiService()
    private var trackingTask: Task<Void, Never>? = nil
    
    private let maximumPageSize: Int32 = 100
    
    // MARK: - Bootstrap
    
    func bootstrap() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        async let catalogTask: Void = loadCatalog()
        async let hierarchyTask: Void = loadLanguages()
        
        _ = await (catalogTask, hierarchyTask)
    }
    
    func loadCatalog() async {
        do {
            self.availableModules = try storeService.loadCatalog()
            // Ensure every module carries its current install status.
            self.availableModules = self.availableModules.map { module in
                var copy = module
                copy.isInstalled = storeService.isModuleInstalled(
                    moduleId: module.uniqueId,
                    version: module.version
                )
                return copy
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func loadLanguages() async {
        do {
            self.languages = try storeService.fetchLanguages(
                first: maximumPageSize,
                skip: 0
            )
            if selectedLanguageID == nil, let first = languages.first {
                selectedLanguageID = first.id
                await loadCollections(forLanguageID: first.id)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Drill-down
    
    func loadCollections(forLanguageID languageID: String) async {
        do {
            guard let language = languages.first(where: { $0.id == languageID }) else { return }
            self.collections = try storeService.fetchCollectionsByLanguage(
                code: language.code,
                first: maximumPageSize,
                skip: 0
            )
            self.albums = []
            self.modulesInAlbum = []
            selectedCollectionID = collections.first?.id
            selectedAlbumID = nil
            if let firstCollection = collections.first {
                await loadAlbums(forCollectionID: firstCollection.id)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func loadAlbums(forCollectionID collectionID: String) async {
        do {
            self.albums = try storeService.fetchAlbumsByCollection(
                collectionId: collectionID,
                first: maximumPageSize,
                skip: 0
            )
            self.modulesInAlbum = []
            selectedAlbumID = albums.first?.id
            if let firstAlbum = albums.first {
                await loadModules(forAlbumID: firstAlbum.id)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func loadModules(forAlbumID albumID: String) async {
        do {
            let album = try storeService.fetchAlbum(id: albumID)
            self.modulesInAlbum = album.modules
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func loadNarrators() async {
        do {
            self.narrators = try storeService.fetchContributorsByRole(
                role: .narrator,
                first: maximumPageSize,
                skip: 0
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Install
    
    func installModule(id: String) {
        trackingTask?.cancel()
        updateModuleProgress(id: id, progress: 0.0)
        
        let progressListener = StoreDownloadProgressListener(uniqueIdFilter: id)
        startProgressTrackingTask(for: id)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let localPath = try self.storeService.installModule(
                    moduleId: id,
                    progressListener: progressListener
                )
                print("Module successfully downloaded to: \(localPath)")
                
                Task { @MainActor in
                    self.trackingTask?.cancel()
                    self.updateModuleStatusToInstalled(id: id)
                }
            } catch {
                Task { @MainActor in
                    self.trackingTask?.cancel()
                    self.errorMessage = error.localizedDescription
                    self.resetModuleStatus(id: id)
                }
            }
        }
    }
    
    // MARK: - Progress tracking
    
    private func startProgressTrackingTask(for moduleId: String) {
        trackingTask = Task(priority: .medium) { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(0.25))
                    let liveCatalog = self.storeService.getCachedCatalog()
                    
                    if let realTimeModule = liveCatalog.first(where: { $0.uniqueId == moduleId }) {
                        if case .downloading(let progress) = realTimeModule.status {
                            self.updateModuleProgress(id: moduleId, progress: progress)
                        }
                        if realTimeModule.isInstalled {
                            self.updateModuleStatusToInstalled(id: moduleId)
                            break
                        }
                    }
                } catch {
                    break
                }
            }
        }
    }
    
    private func updateModuleProgress(id: String, progress: Double) {
        if let index = availableModules.firstIndex(where: { $0.uniqueId == id }) {
            availableModules[index].status = .downloading(progress: progress)
        }
        if let index = modulesInAlbum.firstIndex(where: { $0.uniqueId == id }) {
            modulesInAlbum[index].status = .downloading(progress: progress)
        }
    }
    
    private func updateModuleStatusToInstalled(id: String) {
        if let index = availableModules.firstIndex(where: { $0.uniqueId == id }) {
            availableModules[index].status = .installed
            availableModules[index].isInstalled = true
        }
        if let index = modulesInAlbum.firstIndex(where: { $0.uniqueId == id }) {
            modulesInAlbum[index].status = .installed
            modulesInAlbum[index].isInstalled = true
        }
    }
    
    private func resetModuleStatus(id: String) {
        if let index = availableModules.firstIndex(where: { $0.uniqueId == id }) {
            availableModules[index].status = .idle
        }
        if let index = modulesInAlbum.firstIndex(where: { $0.uniqueId == id }) {
            modulesInAlbum[index].status = .idle
        }
    }
}

extension AudioStoreViewModel {

    /// Modules filtered by the current search text and filter chip.
    /// Matches title, uniqueId, contributor, and features.
    var filteredModules: [RemoteAudioModuleInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return availableModules.filter { module in
            // Filter chip
            switch selectedFilter {
            case .all:
                break
            case .installed:
                if !module.isInstalled { return false }
            case .notInstalled:
                if module.isInstalled { return false }
            case .downloading:
                if case .downloading = module.status { } else { return false }
            }

            // Text search
            if query.isEmpty { return true }
            if module.displayTitle.lowercased().contains(query) { return true }
            if module.uniqueId.lowercased().contains(query) { return true }
            if let c = module.contributor, c.lowercased().contains(query) { return true }
            if module.features.features.contains(where: { $0.lowercased().contains(query) }) {
                return true
            }
            return false
        }
    }

    /// Languages filtered by the current search text.
    var filteredLanguages: [AudioLanguage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return languages }
        return languages.filter {
            $0.name.lowercased().contains(query) ||
            $0.code.lowercased().contains(query)
        }
    }

    /// Narrators filtered by the current search text.
    var filteredNarrators: [AudioContributor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return narrators }
        return narrators.filter { $0.name.lowercased().contains(query) }
    }

    /// True when nothing matches the current search + filter.
    var isEmptyState: Bool {
        searchText.isEmpty
            ? availableModules.isEmpty
            : filteredModules.isEmpty
                && filteredLanguages.isEmpty
                && filteredNarrators.isEmpty
    }
}

// MARK: - Identifiable for sheet(item:)

extension RemoteAudioModuleInfo: @retroactive Identifiable {
    public var id: String { uniqueId }
}
