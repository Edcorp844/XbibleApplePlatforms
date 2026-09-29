//
//  StudyViewModel.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftUI
import XbibleEngine
import SwiftData
import Foundation
import Combine

// MARK: - Study View Model

@MainActor
final class StudyViewModel: ObservableObject {

    // MARK: - Published state

    @Published var tabs: [TabInstance] = []
    @Published var selectedTabId: UUID?
    @Published var showTabOverview: Bool = false

    @Published var availableBibleModules: [XbibleEngine.SwordModule] = []
    @Published var availableBooks: [XbibleEngine.ModuleBook] = []
    @Published var availableNodes: [XbibleEngine.TreeNode] = []
    @Published var availableLexicons: [XbibleEngine.SwordModule] = []
    @Published var availableCommentaries: [XbibleEngine.SwordModule] = []
    @Published var availableGeneraBooks: [XbibleEngine.SwordModule] = []

    // Add to @Published properties:
    @Published var generalBookRoot: XbibleEngine.TreeNode? = nil
    
    
    @Published var selctedTabGroup: TabGroup = TabGroup(name: "My Tabs")
    @Published var tabGroups: [TabGroup] = []

    /// Currently selected search strategy. The engine enum
    /// `XbibleEngine.SearchType` is the source of truth.
    @Published var searchType: SearchType = .multiWord

    // MARK: - Injected dependencies

    private weak var wrapper: SwordEngineWrapper?
    private var modelContext: ModelContext?

    private var engine: XBibleEngine? { wrapper?.engine }
    private var engineQueue: DispatchQueue? { wrapper?.engineQueue }

    // MARK: - Debounced persistence
    private var persistTask: Task<Void, Never>?

    // MARK: - Configuration

    func configure(wrapper: SwordEngineWrapper, modelContext: ModelContext) {
        self.wrapper = wrapper
        self.modelContext = modelContext
    }

    // MARK: - Derived

    var activeTabIndex: Int? {
        guard let id = selectedTabId else { return nil }
        return tabs.firstIndex(where: { $0.id == id })
    }

    var activeTab: TabInstance? {
        guard let idx = activeTabIndex else { return nil }
        return tabs[idx]
    }

    /// Lookup helper for the gallery and other views that need to go
    /// from a tab id to a tab instance.
    func tab(id: UUID) -> TabInstance? {
        tabs.first(where: { $0.id == id })
    }

    var safeDefaultModule: String {
        if let m = wrapper?.selectedModule, !m.isEmpty { return m }
        return availableBibleModules.first?.name ?? ""
    }

    var safeDefaultBook: String {
        if let b = wrapper?.selectedBook, !b.isEmpty { return b }
        return availableBooks.first?.name ?? ""
    }

    var safeDefaultChapter: Int {
        wrapper?.selectedChapter ?? 1
    }

    /// Tabs in the active group, in group order.
    var visibleTabs: [TabInstance] {
        let byId = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        return selctedTabGroup.tabIds.compactMap { byId[$0] }
    }

    // MARK: - Search convenience (used by toolbar / picker)
    var activeTabSearchQuery: String {
        guard let idx = activeTabIndex,
              tabs[idx].type == .search else { return "" }
        return tabs[idx].searchQuery
    }

    var activeTabIsSearchQueryEmpty: Bool {
        activeTabSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var availableModules: [XbibleEngine.SwordModule] {
        guard let activeTab = self.activeTab else { return self.availableBibleModules }
        switch activeTab.type {
        case .bible:
            return self.availableBibleModules
        case .search:
            return self.availableBibleModules
        case .generalBook:
            return self.availableGeneraBooks
        case .dictionary:
            return self.availableLexicons
        case .lexicon:
            return self.availableLexicons
        case .commentary:
            return self.availableCommentaries
        case .parallel:
            return self.availableBibleModules
        }
    }

    // MARK: - Initialization

    func initializeData() {
        guard let engine, let engineQueue else { return }

        engineQueue.async { [weak self] in
            let bibles       = engine.getBibleModules()
            let lexicons     = engine.getLexiconModules()
            let commentaries = engine.getCommentaryModules()
            let books        = engine.getBookModules()

            Task { @MainActor in
                guard let self else { return }
                self.availableBibleModules = bibles
                self.availableLexicons     = lexicons
                self.availableCommentaries = commentaries
                self.availableGeneraBooks  = books

                self.restoreGroups()
                self.ensureDefaultGroup()

                if self.tabs.isEmpty {
                    self.createNewTab(ofType: .bible)
                } else {
                    self.loadContentForActiveTab()
                }
            }
        }
    }

    // MARK: - Group lifecycle

    private func ensureDefaultGroup() {
        if !tabGroups.contains(where: { $0.isPersistent }) {
            tabGroups.append(TabGroup(name: "My Tabs", persistence: .persistent))
        }
        if !tabGroups.contains(where: { $0.isTemporary }) {
            tabGroups.append(TabGroup(name: "Temporary", persistence: .temporary))
        }
        if !tabGroups.contains(where: { $0.id == selctedTabGroup.id }) {
            selctedTabGroup = tabGroups.first!
        }
        if let idx = tabGroups.firstIndex(where: { $0.id == selctedTabGroup.id }) {
            let groupedIds = Set(tabGroups.flatMap { $0.tabIds })
            let orphans = tabs.map(\.id).filter { !groupedIds.contains($0) }
            if !orphans.isEmpty {
                tabGroups[idx].tabIds.append(contentsOf: orphans)
            }
        }
        schedulePersist()
    }

    /// Public hook for the management view after a drag-reorder.
    func persistGroupsOrdering() {
        schedulePersist()
    }

    @discardableResult
    func createGroup(
        name: String,
        persistence: TabGroupPersistence = .persistent,
        seedingWithCurrentTab: Bool = false
    ) -> TabGroup {
        var group = TabGroup(name: name, persistence: persistence)

        if seedingWithCurrentTab, let active = activeTab {
            group.tabIds = [active.id]
        }

        tabGroups.append(group)
        selctedTabGroup = group
        schedulePersist()
        return group
    }

    func selectGroup(_ group: TabGroup) {
        selctedTabGroup = group
        if let firstTabId = group.tabIds.first,
           tabs.contains(where: { $0.id == firstTabId }) {
            selectedTabId = firstTabId
        } else {
            selectedTabId = nil
        }
    }

    func renameGroup(_ groupId: UUID, name: String) {
        guard let idx = tabGroups.firstIndex(where: { $0.id == groupId }) else { return }
        tabGroups[idx].name = name
        if selctedTabGroup.id == groupId { selctedTabGroup = tabGroups[idx] }
        schedulePersist()
    }

    func setGroupPersistence(_ groupId: UUID, _ persistence: TabGroupPersistence) {
        guard let idx = tabGroups.firstIndex(where: { $0.id == groupId }) else { return }
        tabGroups[idx].persistence = persistence
        if selctedTabGroup.id == groupId { selctedTabGroup = tabGroups[idx] }
        schedulePersist()
    }

    func toggleGroupPersistence(_ groupId: UUID) {
        guard let idx = tabGroups.firstIndex(where: { $0.id == groupId }) else { return }
        tabGroups[idx].persistence =
            tabGroups[idx].persistence == .persistent ? .temporary : .persistent
        if selctedTabGroup.id == groupId { selctedTabGroup = tabGroups[idx] }
        schedulePersist()
    }

    func deleteGroup(_ groupId: UUID, closeContainedTabs: Bool = true) {
        guard let group = tabGroups.first(where: { $0.id == groupId }) else { return }

        if closeContainedTabs {
            tabs.removeAll { group.tabIds.contains($0.id) }
        }

        tabGroups.removeAll { $0.id == groupId }
        ensureDefaultGroup()

        if !tabGroups.contains(where: { $0.id == selctedTabGroup.id }) {
            selctedTabGroup = tabGroups[0]
        }
        schedulePersist()
    }

    func moveTab(_ tabId: UUID, toGroup groupId: UUID) {
        for i in tabGroups.indices {
            tabGroups[i].tabIds.removeAll { $0 == tabId }
        }
        guard let idx = tabGroups.firstIndex(where: { $0.id == groupId }) else { return }
        tabGroups[idx].tabIds.append(tabId)
        tabGroups[idx].lastActivatedAt = .now

        if selctedTabGroup.id == groupId {
            selectedTabId = tabId
        }
        schedulePersist()
    }

    // MARK: - Tab lifecycle

    func createNewTab(ofType type: TabType) {
        var tab = TabInstance()
        tab.type = type

        switch type {
        case .bible, .parallel:
            tab.selectedModule  = safeDefaultModule
            tab.selectedBook    = safeDefaultBook
            tab.selectedChapter = safeDefaultChapter

        case .generalBook:
            tab.selectedModule = availableGeneraBooks.first?.name ?? ""

        case .search:
            if let active = activeTab, !active.selectedModule.isEmpty {
                tab.selectedModule = active.selectedModule
            } else {
                tab.selectedModule = safeDefaultModule
            }
            tab.searchType = searchType

        case .commentary:
            tab.selectedBook    = safeDefaultBook
            tab.selectedChapter = safeDefaultChapter
            tab.selectedCommentaryModule = availableCommentaries.first?.name ?? ""

        case .dictionary, .lexicon:
            break
        }

        tabs.append(tab)
        selectedTabId = tab.id

        if let groupIdx = tabGroups.firstIndex(where: { $0.id == selctedTabGroup.id }) {
            tabGroups[groupIdx].tabIds.append(tab.id)
        }

        switch type {
        case .bible, .parallel:
            if !tab.selectedModule.isEmpty { updateBooks() }

        case .generalBook:
            if !tab.selectedModule.isEmpty { updateGeneralBookNodes() }

        case .commentary:
            loadCommentaryContent()

        default:
            break
        }

        schedulePersist()
    }

    func duplicateCurrentTab() {
        guard let idx = activeTabIndex else {
            createNewTab(ofType: .bible)
            return
        }
        duplicateTab(id: tabs[idx].id)
    }

    func duplicateTab(id: UUID) {
        guard let source = tabs.first(where: { $0.id == id }) else { return }

        var copy = TabInstance()
        copy.type                    = source.type
        copy.selectedModule          = source.selectedModule
        copy.selectedBook            = source.selectedBook
        copy.selectedChapter         = source.selectedChapter
        copy.selectedGeneralBookNodeId = source.selectedGeneralBookNodeId
        copy.searchQuery             = source.searchQuery
        copy.searchType              = source.searchType
        copy.selectedWordForLookup   = source.selectedWordForLookup
        copy.selectedStrongsForLookup = source.selectedStrongsForLookup
        copy.selectedLexiconModule   = source.selectedLexiconModule
        copy.selectedCommentaryModule = source.selectedCommentaryModule
        copy.currentCommentaryReference = source.currentCommentaryReference

        tabs.append(copy)
        selectedTabId = copy.id

        if let sourceGroupIdx = tabGroups.firstIndex(where: { $0.tabIds.contains(source.id) }) {
            tabGroups[sourceGroupIdx].tabIds.append(copy.id)
        } else if let groupIdx = tabGroups.firstIndex(where: { $0.id == selctedTabGroup.id }) {
            tabGroups[groupIdx].tabIds.append(copy.id)
        }

        switch copy.type {
        case .bible, .parallel:
            updateBooks()

        case .generalBook:
            updateGeneralBookNodes()

        case .search:
            searchType = copy.searchType
            if !copy.searchQuery.isEmpty { performSearch(copy.searchQuery) }

        case .dictionary:
            if !copy.selectedWordForLookup.isEmpty {
                lookupWord(text: copy.selectedWordForLookup)
            }

        case .lexicon:
            if !copy.selectedStrongsForLookup.isEmpty {
                lookupStrongs(copy.selectedStrongsForLookup)
            }

        case .commentary:
            loadCommentaryContent()
        }

        schedulePersist()
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedTabId == id

        for i in tabGroups.indices {
            tabGroups[i].tabIds.removeAll { $0 == id }
        }

        tabs.remove(at: index)

        if wasSelected {
            if let nextInGroup = selctedTabGroup.tabIds.first(where: { gid in
                tabs.contains(where: { $0.id == gid })
            }) {
                selectedTabId = nextInGroup
            } else if tabs.indices.contains(index) {
                selectedTabId = tabs[index].id
            } else {
                selectedTabId = tabs.last?.id
            }
            loadContentForActiveTab()
        }

        schedulePersist()
    }

    func closeOtherTabs(keeping id: UUID) {
        tabs = tabs.filter { $0.id == id }
        for i in tabGroups.indices {
            tabGroups[i].tabIds = tabGroups[i].tabIds.filter { $0 == id }
        }
        selectedTabId = id
        loadContentForActiveTab()
        schedulePersist()
    }

    func closeAllTabs() {
        tabs.removeAll()
        for i in tabGroups.indices {
            tabGroups[i].tabIds.removeAll()
        }
        selectedTabId = nil
        schedulePersist()
    }

    func selectTab(id: UUID) {
        selectedTabId = id
        if let idx = activeTabIndex, tabs[idx].type == .search {
            searchType = tabs[idx].searchType
        }
        loadContentForActiveTab()
    }

    // MARK: - Content loading

    func loadContentForActiveTab() {
        guard let idx = activeTabIndex else { return }
        let tab = tabs[idx]

        switch tab.type {
        case .bible, .parallel:
            updateBooks()

        case .generalBook:
            updateGeneralBookNodes()

        case .search:
            searchType = tab.searchType
            if !tab.searchQuery.isEmpty { performSearch(tab.searchQuery) }

        case .dictionary:
            if !tab.selectedWordForLookup.isEmpty {
                lookupWord(text: tab.selectedWordForLookup)
            }

        case .lexicon:
            if !tab.selectedStrongsForLookup.isEmpty {
                lookupStrongs(tab.selectedStrongsForLookup)
            }

        case .commentary:
            loadCommentaryContent()
        }
    }

    func selectModule(_ moduleName: String) {
        guard let idx = activeTabIndex else { return }
        tabs[idx].selectedModule = moduleName
        updateBooks()
    }

    func selectCommentaryModule(_ moduleName: String) {
        guard let idx = activeTabIndex else { return }
        tabs[idx].selectedCommentaryModule = moduleName
        loadCommentaryContent()
    }

    func selectBook(_ bookName: String) {
        guard let idx = activeTabIndex else { return }
        tabs[idx].selectedBook = bookName
        tabs[idx].selectedChapter = 1
        loadContent()
    }

    func selectChapter(_ chapter: Int) {
        guard let idx = activeTabIndex else { return }
        tabs[idx].selectedChapter = chapter
        loadContent()
    }

    // MARK: - Bible content

    func updateBooks() {
        guard let engine, let engineQueue,
              let tabId = selectedTabId,
              let index = tabs.firstIndex(where: { $0.id == tabId }),
              tabs[index].type.usesReaderPane
        else { return }

        var currentModule = tabs[index].selectedModule
        if currentModule.isEmpty {
            currentModule = availableBibleModules.first?.name ?? ""
        }

        guard !currentModule.isEmpty else {
            availableBooks = []
            return
        }

        let capturedTabId = tabId

        engineQueue.async { [weak self] in
            let books = engine.getBooks(moduleName: currentModule)

            Task { @MainActor in
                guard let self else { return }
                self.availableBooks = books

                guard let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId }) else { return }

                if self.tabs[idx].selectedModule.isEmpty {
                    self.tabs[idx].selectedModule = currentModule
                }

                if !books.contains(where: { $0.name == self.tabs[idx].selectedBook }) {
                    self.tabs[idx].selectedBook = books.first?.name ?? ""
                    self.tabs[idx].selectedChapter = 1
                }

                self.loadContent()
            }
        }
    }

    func loadContent() {
        guard let engine, let engineQueue,
              let tabId = selectedTabId,
              let index = tabs.firstIndex(where: { $0.id == tabId })
        else { return }

        let tab = tabs[index]
        guard tab.type.usesReaderPane else { return }

        guard !tab.selectedBook.isEmpty else {
            if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
                tabs[idx].sections = []
            }
            return
        }

        var currentModule = tab.selectedModule
        if currentModule.isEmpty {
            currentModule = availableBibleModules.first?.name ?? ""
        }
        guard !currentModule.isEmpty else { return }

        let ref = "\(tab.selectedBook) \(tab.selectedChapter)"
        let capturedTabId = tabId

        engineQueue.async { [weak self] in
            let results = engine.getChapterContent(moduleName: currentModule, reference: ref)

            Task { @MainActor in
                guard let self,
                      let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId })
                else { return }

                var updated = self.tabs[idx]
                updated.sections = results
                self.tabs[idx] = updated

                self.loadCommentaryContent()
            }
        }
    }

    // MARK: - General Book

    func selectGeneralBookModule(_ moduleName: String) {
        guard let idx = activeTabIndex,
              tabs[idx].type == .generalBook
        else { return }
        tabs[idx].selectedModule = moduleName
        tabs[idx].selectedGeneralBookNodeId = nil
        updateGeneralBookNodes()
    }

    /// Fetch the tree structure for the active general-book tab,
    /// flatten it to leaf nodes, and publish them.
    func updateGeneralBookNodes() {
        guard let engine, let engineQueue,
              let tabId = selectedTabId,
              let index = tabs.firstIndex(where: { $0.id == tabId }),
              tabs[index].type == .generalBook
        else { return }

        var currentModule = tabs[index].selectedModule
        if currentModule.isEmpty {
            currentModule = availableGeneraBooks.first?.name ?? ""
        }
        guard !currentModule.isEmpty,
              let swordModule = availableGeneraBooks.first(where: { $0.name == currentModule })
        else {
            availableNodes = []
            generalBookRoot = nil     
            return
        }

        let capturedTabId = tabId

        engineQueue.async { [weak self] in
            let root = engine.getGeneralBookStructure(bookModule: swordModule)
            let leaves = Self.collectLeafNodes(root: root)

            Task { @MainActor in
                guard let self else { return }
                self.availableNodes = leaves
                self.generalBookRoot = root

                guard let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId })
                else { return }

                if self.tabs[idx].selectedModule.isEmpty {
                    self.tabs[idx].selectedModule = currentModule
                }

                let currentId = self.tabs[idx].selectedGeneralBookNodeId
                let stillValid = currentId.flatMap { id in
                    leaves.contains(where: { $0.id == id })
                } ?? false

                if !stillValid {
                    self.tabs[idx].selectedGeneralBookNodeId = leaves.first?.id
                }

                self.loadGeneralBookContent()
            }
        }
    }

    /// Fetch and publish `sections` for the currently selected
    /// general-book leaf.
    func loadGeneralBookContent() {
        guard let engine, let engineQueue,
              let tabId = selectedTabId,
              let index = tabs.firstIndex(where: { $0.id == tabId }),
              tabs[index].type == .generalBook
        else { return }

        let tab = tabs[index]
        guard let nodeId = tab.selectedGeneralBookNodeId,
              let leaf = availableNodes.first(where: { $0.id == nodeId }),
              let swordModule = availableGeneraBooks.first(where: { $0.name == tab.selectedModule })
        else {
            if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
                tabs[idx].sections = []
            }
            return
        }

        let capturedTabId = tabId

        engineQueue.async { [weak self] in
            // NOTE: engine API has a typo — `getGenearlBookContent`.
            let sections = engine.getGenearlBookContent(bookModule: swordModule, node: leaf)

            Task { @MainActor in
                guard let self,
                      let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId })
                else { return }

                var updated = self.tabs[idx]
                updated.sections = sections
                self.tabs[idx] = updated
            }
        }
    }

    /// Select a general-book leaf node and load its content.
    func selectGeneralBookNode(id: UInt32) {
        guard let idx = activeTabIndex,
              tabs[idx].type == .generalBook
        else { return }
        tabs[idx].selectedGeneralBookNodeId = id
        loadGeneralBookContent()
    }

    /// Recursively collect leaf nodes (nodes with no children).
    /// Skips the synthetic "/" root.
    private static func collectLeafNodes(root: TreeNode) -> [TreeNode] {
        var leaves: [TreeNode] = []
        if root.children.isEmpty {
            if root.path != "/" {
                leaves.append(root)
            }
        } else {
            for child in root.children {
                leaves.append(contentsOf: collectLeafNodes(root: child))
            }
        }
        return leaves
    }

    // MARK: - Search

    func performSearch(_ query: String) {
        guard let engine, let engineQueue,
              let idx = activeTabIndex,
              tabs[idx].type == .search
        else { return }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            tabs[idx].searchResults = []
            tabs[idx].searchHitsContent = [:]
            tabs[idx].isSearching = false
            return
        }

        tabs[idx].searchQuery = trimmed
        tabs[idx].isSearching = true

        let moduleName = tabs[idx].selectedModule.isEmpty
            ? safeDefaultModule
            : tabs[idx].selectedModule
        guard !moduleName.isEmpty else {
            tabs[idx].isSearching = false
            return
        }

        guard let swordModule = availableBibleModules.first(where: { $0.name == moduleName }) else {
            tabs[idx].isSearching = false
            return
        }

        let type = searchType
        tabs[idx].searchType = type

        let capturedTabId = tabs[idx].id

        engineQueue.async { [weak self] in
            guard let self, let engine = self.engine else { return }

            let response = engine.search(
                moduleName: moduleName,
                query: trimmed,
                searchType: type
            )
            let hits = response.hits

            var contentMap: [String: [ModuleSection]] = [:]
            for hit in hits {
                contentMap[hit.key] = engine.getSingleEntry(
                    swordModule: swordModule,
                    reference: hit.key
                )
            }

            Task { @MainActor [weak self] in
                guard let self,
                      let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId })
                else { return }

                self.tabs[idx].searchResults     = hits
                self.tabs[idx].searchHitsContent = contentMap
                self.tabs[idx].isSearching       = false
            }
        }
    }

    func updateSearchQuery(_ query: String) {
        guard let idx = activeTabIndex, tabs[idx].type == .search else { return }
        tabs[idx].searchQuery = query
    }

    func updateSearchType(_ type: SearchType) {
        searchType = type
        guard let idx = activeTabIndex, tabs[idx].type == .search else { return }
        tabs[idx].searchType = type
        if !tabs[idx].searchQuery.isEmpty {
            performSearch(tabs[idx].searchQuery)
        }
    }

    func clearSearch() {
        guard let idx = activeTabIndex, tabs[idx].type == .search else { return }
        tabs[idx].searchQuery = ""
        tabs[idx].searchResults = []
        tabs[idx].searchHitsContent = [:]
    }

    // MARK: - Lookups

    func lookupWord(text: String, language: String = "en") {
        guard let engine, let engineQueue,
              !text.isEmpty,
              let idx = activeTabIndex
        else { return }

        tabs[idx].selectedWordForLookup = text
        tabs[idx].selectedTab = .dictionary
        tabs[idx].isDictionaryLoading = true

        if tabs[idx].type.usesReaderPane {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tabs[idx].isSplitViewPresented = true
            }
        }

        let query = DictionaryQuery(word: text, strongs: [], language: language)
        let capturedTabId = tabs[idx].id

        engineQueue.async { [weak self] in
            let response = engine.lookupDictionary(query: query)

            Task { @MainActor in
                guard let self,
                      let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId })
                else { return }

                var updated = self.tabs[idx]
                updated.dictionaryResults = response.results
                updated.isDictionaryLoading = false
                self.tabs[idx] = updated
            }
        }
    }

    func lookupWord(_ word: Word) {
        let clean = word.text.trimmingCharacters(in: .punctuationCharacters)
        guard !clean.isEmpty else { return }
        lookupWord(text: clean, language: word.language)
    }

    func lookupStrongs(_ strongsCode: String) {
        guard let engine, let engineQueue,
              !strongsCode.isEmpty,
              let idx = activeTabIndex
        else { return }

        tabs[idx].selectedStrongsForLookup = strongsCode
        tabs[idx].selectedTab = .lexicon

        if tabs[idx].type.usesReaderPane {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tabs[idx].isSplitViewPresented = true
            }
        }

        if availableLexicons.isEmpty {
            loadLexiconsMetadata { [weak self] in
                self?.loadLexiconContent()
            }
        } else {
            loadLexiconContent()
        }
    }

    func loadLexiconsMetadata(completion: (() -> Void)? = nil) {
        guard let engine, let engineQueue else { return }

        engineQueue.async { [weak self] in
            let lexicons = engine.getLexiconModules()

            Task { @MainActor in
                guard let self else { return }
                self.availableLexicons = lexicons

                if let idx = self.activeTabIndex {
                    let current = self.tabs[idx].selectedLexiconModule
                    if current.isEmpty || !lexicons.contains(where: { $0.name == current }) {
                        self.tabs[idx].selectedLexiconModule = lexicons.first?.name ?? ""
                    }
                }
                completion?()
            }
        }
    }

    func loadLexiconContent() {
        guard let engine, let engineQueue,
              let idx = activeTabIndex
        else { return }

        let tab = tabs[idx]
        guard !tab.selectedStrongsForLookup.isEmpty else {
            tabs[idx].lexiconResults = []
            return
        }

        tabs[idx].isLexiconLoading = true

        let reference = tab.selectedStrongsForLookup
        let module = tab.selectedLexiconModule
        let targetLanguage = availableLexicons
            .first(where: { $0.name == module })?
            .language ?? "en"
        let capturedTabId = tab.id

        engineQueue.async { [weak self] in
            let query = LexiconQuery(strongsNumber: reference, language: targetLanguage)
            let response = engine.lookupStrongsNumber(query: query)

            Task { @MainActor in
                guard let self,
                      let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId })
                else { return }

                var updated = self.tabs[idx]
                updated.lexiconResults = response.results
                updated.isLexiconLoading = false
                self.tabs[idx] = updated
            }
        }
    }

    func selectLexiconModule(_ moduleName: String) {
        guard let idx = activeTabIndex else { return }
        tabs[idx].selectedLexiconModule = moduleName
        loadLexiconContent()
    }

    // MARK: - Commentary

    func loadCommentaryContent() {
        guard let engine, let engineQueue,
              let idx = activeTabIndex
        else { return }

        let tab = tabs[idx]
        guard !tab.selectedCommentaryModule.isEmpty else {
            tabs[idx].commentaryResults = []
            return
        }

        tabs[idx].isCommentaryLoading = true

        let module = tab.selectedCommentaryModule
        let reference = "\(tab.selectedBook) \(tab.selectedChapter)"
        tabs[idx].currentCommentaryReference = reference
        let capturedTabId = tab.id

        engineQueue.async { [weak self] in
            let results = engine.getChapterContent(
                moduleName: module,
                reference: reference
            )

            Task { @MainActor in
                guard let self,
                      let idx = self.tabs.firstIndex(where: { $0.id == capturedTabId })
                else { return }

                var updated = self.tabs[idx]
                updated.commentaryResults = results
                updated.isCommentaryLoading = false
                self.tabs[idx] = updated
            }
        }
    }

    // MARK: - Persistence

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.persistGroups()
        }
    }

    private func persistGroups() {
        let persistent = tabGroups.filter { $0.persistence == .persistent }
        if let data = try? JSONEncoder().encode(persistent) {
            UserDefaults.standard.set(data, forKey: "xbible.tabGroups.persistent")
        }
        UserDefaults.standard.set(
            selctedTabGroup.id.uuidString,
            forKey: "xbible.selectedGroupId"
        )
    }

    private func restoreGroups() {
        var restored: [TabGroup] = []
        if let data = UserDefaults.standard.data(forKey: "xbible.tabGroups.persistent"),
           let groups = try? JSONDecoder().decode([TabGroup].self, from: data) {
            restored = groups.map { g in
                var copy = g
                copy.persistence = .persistent
                return copy
            }
        }
        tabGroups = restored

        if let idString = UserDefaults.standard.string(forKey: "xbible.selectedGroupId"),
           let id = UUID(uuidString: idString),
           let match = tabGroups.first(where: { $0.id == id }) {
            selctedTabGroup = match
        } else if let first = tabGroups.first {
            selctedTabGroup = first
        }
    }

    // MARK: - Bible chapter navigation

    func canGoToPrevious() -> Bool {
        guard let idx = activeTabIndex,
              tabs[idx].type.usesReaderPane,
              let bookIndex = availableBooks.firstIndex(where: { $0.name == tabs[idx].selectedBook })
        else { return false }

        return tabs[idx].selectedChapter > 1 || bookIndex > 0
    }

    func canGoToNext() -> Bool {
        guard let idx = activeTabIndex,
              tabs[idx].type.usesReaderPane,
              let bookIndex = availableBooks.firstIndex(where: { $0.name == tabs[idx].selectedBook })
        else { return false }

        let chapters = availableBooks[bookIndex].chapters
        return tabs[idx].selectedChapter < chapters.count
            || bookIndex < availableBooks.count - 1
    }

    func goToPreviousChapter() {
        guard let idx = activeTabIndex,
              tabs[idx].type.usesReaderPane,
              let bookIndex = availableBooks.firstIndex(where: { $0.name == tabs[idx].selectedBook })
        else { return }

        if tabs[idx].selectedChapter > 1 {
            tabs[idx].selectedChapter -= 1
        } else if bookIndex > 0 {
            let prev = availableBooks[bookIndex - 1]
            tabs[idx].selectedBook = prev.name
            tabs[idx].selectedChapter = prev.chapters.count
        }
        loadContent()
    }

    func goToNextChapter() {
        guard let idx = activeTabIndex,
              tabs[idx].type.usesReaderPane,
              let bookIndex = availableBooks.firstIndex(where: { $0.name == tabs[idx].selectedBook })
        else { return }

        let chapters = availableBooks[bookIndex].chapters

        if tabs[idx].selectedChapter < chapters.count {
            tabs[idx].selectedChapter += 1
        } else if bookIndex < availableBooks.count - 1 {
            let next = availableBooks[bookIndex + 1]
            tabs[idx].selectedBook = next.name
            tabs[idx].selectedChapter = 1
        }
        loadContent()
    }

    // MARK: - General book leaf navigation

    func canGoToPreviousGeneralBookNode() -> Bool {
        guard let idx = activeTabIndex,
              tabs[idx].type == .generalBook,
              let currentId = tabs[idx].selectedGeneralBookNodeId,
              let pos = availableNodes.firstIndex(where: { $0.id == currentId })
        else { return false }
        return pos > 0
    }

    func canGoToNextGeneralBookNode() -> Bool {
        guard let idx = activeTabIndex,
              tabs[idx].type == .generalBook,
              let currentId = tabs[idx].selectedGeneralBookNodeId,
              let pos = availableNodes.firstIndex(where: { $0.id == currentId })
        else { return false }
        return pos < availableNodes.count - 1
    }

    func goToPreviousGeneralBookNode() {
        guard let idx = activeTabIndex,
              tabs[idx].type == .generalBook,
              let currentId = tabs[idx].selectedGeneralBookNodeId,
              let pos = availableNodes.firstIndex(where: { $0.id == currentId }),
              pos > 0
        else { return }
        selectGeneralBookNode(id: availableNodes[pos - 1].id)
    }

    func goToNextGeneralBookNode() {
        guard let idx = activeTabIndex,
              tabs[idx].type == .generalBook,
              let currentId = tabs[idx].selectedGeneralBookNodeId,
              let pos = availableNodes.firstIndex(where: { $0.id == currentId }),
              pos < availableNodes.count - 1
        else { return }
        selectGeneralBookNode(id: availableNodes[pos + 1].id)
    }
}
