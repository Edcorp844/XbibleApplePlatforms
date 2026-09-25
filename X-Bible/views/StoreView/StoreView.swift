//
//  StoreView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI
import XbibleEngine
import SwiftData

struct StoreView: View {

    // MARK: - Environment

    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var viewModel = StoreViewModel()
    @State private var selectedCategory: String = "All"
    @State private var expandedLanguages: Set<String> = []
    @State private var showSourcePicker: Bool = false
    @State private var searchText: String = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            catalogStack
                .navigationTitle("Store")
                .searchable(
                    text: $searchText,
                    placement: .toolbar,
                    prompt: "Search ..."
                )
                .refreshable {
                    await refresh()
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        sourcePickerButton
                    }
                }
                .onAppear {
                    viewModel.setup(modelContext: modelContext, wrapper: wrapper)
                }
                .onChange(of: viewModel.modulesForCurrentSource) { _, _ in
                    updateSelectedCategory()
                }
                .onChange(of: searchText) { _, _ in
                    // Auto-expand languages that still have matches
                    expandedLanguages = Set(filteredLanguages.keys)
                }
        }
    }

    // MARK: - Catalog stack

    private var catalogStack: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                mainCatalogContent
            }
        }
        .safeAreaInset(edge: .top) {
            DynamicCategoryTabBar(
                categories: availableCategories,
                selection: $selectedCategory
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var mainCatalogContent: some View {
        if viewModel.isLoading && viewModel.organizedModules.isEmpty {
            ProgressView("Loading modules…")
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
                        AnyView(bookView(for: module))
                    },
                    isExpanded: expandedLanguages.contains(langCode),
                    toggle: { toggleLanguage(langCode) }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.15), value: searchText)
    }

    // MARK: - Dynamic Categories

    private var availableCategories: [String] {
        let keys = viewModel.organizedModules.keys.sorted()
        return ["All"] + keys
    }

    /// Base data for the currently selected category (before search filter)
    private var languagesForSelectedCategory: [String: [XbibleEngine.SwordModule]] {
        if selectedCategory == "All" {
            var merged: [String: [XbibleEngine.SwordModule]] = [:]
            for (_, langDict) in viewModel.organizedModules {
                for (lang, modules) in langDict {
                    merged[lang, default: []].append(contentsOf: modules)
                }
            }
            return merged
        } else {
            return viewModel.organizedModules[selectedCategory] ?? [:]
        }
    }

    /// Final data shown in the list = category + search filter
    private var filteredLanguages: [String: [XbibleEngine.SwordModule]] {
        let base = languagesForSelectedCategory
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

    /// Search across name, description, category, language, source, version, delta, features
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

        // Features array
        if module.features.contains(where: { $0.lowercased().contains(query) }) {
            return true
        }

        return false
    }

    // MARK: - Source Picker

    @ViewBuilder
    private var sourcePickerButton: some View {
        let label = viewModel.currentSource?.name ?? "Select Source"

        PopoverButton(
            label: label,
            title: "Select Source",
            isPresented: $showSourcePicker,
            bypassPopover: false
        ) {
            sourcePickerContent
        }
    }

    @ViewBuilder
    private var sourcePickerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.availableSources.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.availableSources, id: \.name) { source in
                    sourceRow(source)
                }
            }
        }
        #if os(macOS)
        .padding(12)
        .frame(minWidth: 220)
        #else
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        #endif
    }

    private func sourceRow(_ source: XbibleEngine.ModuleSource) -> some View {
        let isSelected = viewModel.currentSource?.name == source.name

        return Button {
            viewModel.selectSource(source, wrapper: wrapper)
            showSourcePicker = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(source.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty / Helpers

    private var emptyState: some View {
        Group {
            if searchText.isEmpty {
                ContentUnavailableView("No Modules", systemImage: "magnifyingglass")
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

    private func bookView(for module: XbibleEngine.SwordModule) -> some View {
        let status = viewModel.installationStates[module.name] ?? .idle

        return BookCardView(
            module: module,
            status: status,
            showActionButton: true,
            action: {
                let currentStatus = viewModel.installationStates[module.name] ?? .idle
                handleAction(for: module, status: currentStatus)
            }
        )
        .overlay(alignment: .topTrailing) {
            sourceLabel(for: module.source)
        }
        .id("\(module.name)-\(statusID(status))")
    }

    private func sourceLabel(for source: String) -> some View {
        Text(source)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(4)
            .padding(8)
    }

    private func handleAction(for module: XbibleEngine.SwordModule, status: InstallationStatus) {
        switch status {
        case .idle, .cancelled:
            viewModel.install(module: module, wrapper: wrapper)
        case .installed:
            print("Open module: \(module.name)")
        case .pending, .installing:
            viewModel.cancelInstall(moduleName: module.name)
        }
    }

    private func statusID(_ status: InstallationStatus) -> String {
        switch status {
        case .idle:       return "idle"
        case .cancelled:  return "cancelled"
        case .installed:  return "installed"
        case .pending:    return "pending"
        case .installing: return "installing"
        }
    }

    private func toggleLanguage(_ langCode: String) {
        if expandedLanguages.contains(langCode) {
            expandedLanguages.remove(langCode)
        } else {
            expandedLanguages.insert(langCode)
        }
    }

    private func updateSelectedCategory() {
        let cats = availableCategories
        if !cats.contains(selectedCategory) {
            selectedCategory = cats.first ?? "All"
        }
        expandedLanguages = Set(filteredLanguages.keys)
    }

    private func refresh() async {
        await withCheckedContinuation { continuation in
            viewModel.refreshStore()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                continuation.resume()
            }
        }
    }
}

// MARK: - Dynamic Tab Bar

struct DynamicCategoryTabBar: View {
    let categories: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(categories, id: \.self) { category in
                    tabButton(for: category)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 38)
    }

    @ViewBuilder
    private func tabButton(for category: String) -> some View {
        let isActive = selection == category

        Button {
            withAnimation(.interpolatingSpring(duration: 0.3, bounce: 0)) {
                selection = category
            }
        } label: {
            HStack(spacing: 6) {
                Text(category)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
            }
            .foregroundStyle(isActive ? .white : .primary)
            .padding(.horizontal, isActive ? 16 : 12,)
            .padding(.vertical, 4)
            
           
        }
        .background {
            isActive ? Color.accentColor : .primary.opacity(0.3)
        }
        .buttonStyle(.glass)
        .clipShape(Capsule())
        
    }
}
