//
//  LibraryView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/22/26.
//

import SwiftUI
import XbibleEngine

struct LibraryView: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @StateObject private var viewModel = LibraryViewModel()
    
    @State private var searchText: String = ""
    
    let category: SidebarItem
    
    // For the detail sheet
    @State private var moduleToShowDetails: XbibleEngine.SwordModule? = nil

    var body: some View {
        ScrollView {
            mainContent
                .padding(.vertical, 12)
        }
        .searchable(
            text: $searchText,
            placement: horizontalSizeClass == .regular ? .toolbar : .toolbarPrincipal,
            prompt: "Search modules…"
        )
        .refreshable {
            viewModel.refreshModules(wrapper: wrapper, category: category)
        }
        .navigationTitle(category.title)
        .navigationSubtitle("\(viewModel.installedModules.count) modules")
        .onAppear {
            viewModel.loadInstalledModules(wrapper: wrapper, category: category)
        }
        .onReceive(NotificationCenter.default.publisher(for: .installationStateChanged)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.loadInstalledModules(wrapper: wrapper, category: category)
            }
        }
        .onChange(of: wrapper.engineVersion) { _, _ in
            viewModel.loadInstalledModules(wrapper: wrapper, category: category)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.modulesByLanguage.isEmpty {
            ProgressView("Loading library…")
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else if filteredLanguages.isEmpty {
            emptyState
        } else {
            languageList
        }
    }

    private var languageList: some View {
        let languages = filteredLanguages

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(languages.keys.sorted(), id: \.self) { langCode in
                LanguageSection(
                    langCode: langCode,
                    count: languages[langCode]?.count ?? 0,
                    modules: languages[langCode] ?? [],
                    bookViewBuilder: { module in
                        AnyView(
                            BookCardView(
                                module: module,
                                status: .installed,
                                showActionButton: false,
                                action: {
                                    wrapper.openModuleInStudy(module)
                                },
                                categoryName: category.title,
                                menuAction: {
                                    // Optional menu action
                                }
                            )
                            .contextMenu {
                                libraryContextMenu(for: module)
                            }
                        )
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.15), value: searchText)
    }

    // MARK: - Filtering

    private var filteredLanguages: [String: [XbibleEngine.SwordModule]] {
        let base = viewModel.modulesByLanguage
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !query.isEmpty else { return base }

        var result: [String: [XbibleEngine.SwordModule]] = [:]

        for (langCode, modules) in base {
            let matching = modules.filter { module in
                matches(module, query: query, languageCode: langCode)
            }
            if !matching.isEmpty {
                result[langCode] = matching
            }
        }
        return result
    }

    private func matches(
        _ module: XbibleEngine.SwordModule,
        query: String,
        languageCode: String
    ) -> Bool {
        if module.name.lowercased().contains(query) { return true }
        if module.description.lowercased().contains(query) { return true }
        if module.category.lowercased().contains(query) { return true }
        if module.language.lowercased().contains(query) { return true }
        if languageCode.lowercased().contains(query) { return true }
        if module.source.lowercased().contains(query) { return true }
        if module.version.lowercased().contains(query) { return true }
        if module.delta.lowercased().contains(query) { return true }

        if module.features.contains(where: { $0.lowercased().contains(query) }) {
            return true
        }

        return false
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func libraryContextMenu(for module: XbibleEngine.SwordModule) -> some View {
        Button {
            wrapper.openModuleInStudy(module)
        } label: {
            Label("Open", systemImage: "book")
        }

        Button {
            moduleToShowDetails = module
        } label: {
            Label("Show Details", systemImage: "info.circle")
        }

        Divider()

        Button(role: .destructive) {
            // TODO: Uninstall logic
            print("Uninstall \(module.name)")
        } label: {
            Label("Uninstall", systemImage: "trash")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Group {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "No Installed Modules",
                    systemImage: "books.vertical",
                    description: Text("Modules you install will appear here.")
                )
            } else {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No modules match “\(searchText)”")
                )
            }
        }
        .padding(.top, 100)
    }
}
