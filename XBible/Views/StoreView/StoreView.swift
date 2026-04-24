//
//  StoreView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine

struct StoreView: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = StoreViewModel()
    
    @State private var selectedCategory: String = "Biblical Texts"
    @State private var expandedLanguages: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                VStack(spacing: 0) {
                    ProgressView(value: viewModel.globalDownloadDetails?.progress ?? 0.0, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)

                    HStack {
                        Text("Fetching catalog...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.globalDownloadDetails?.status ?? "Waiting...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int((viewModel.globalDownloadDetails?.progress ?? 0.0) * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 2. Category Picker (Transparent Background)
            categoryPicker
            
            // 3. Main Content
            ScrollView {
                if !viewModel.searchText.isEmpty {
                    searchResultsContent
                } else {
                    mainCatalogContent
                }
            }
        }
        .navigationTitle("Store")
        .navigationSubtitle(viewModel.selectedSource)
        .searchable(text: $viewModel.searchText, prompt: "Search for bibles, commentaries, cults...")
        .onAppear {
            viewModel.setup(modelContext: modelContext, wrapper: wrapper)
            viewModel.loadStore(wrapper: wrapper) 
        }
        .toolbar {
            sourceToolbarItem
        }
        .onChange(of: viewModel.remoteModules) { _ in
            let organized = viewModel.organizedModules
            
            // Auto-select first category
            if let first = organized.keys.sorted().first {
                selectedCategory = first
            }
            
            // Expand everything by default
            let allLangCodes = organized.values.flatMap { $0.keys }
            expandedLanguages = Set(allLangCodes)
        }
    }

    private var bookViewBuilder: (XbibleEngine.SwordModule) -> BookCardView {
        { module in
            let status = viewModel.installationStates[module.name] ?? .idle
            return BookCardView(
                module: module,
                status: status,
                showActionButton: true,
                action: {
                    if status == .idle || status == .cancelled {
                        viewModel.install(module: module, wrapper: wrapper)
                    } else if status == .installed {
                        print("Open module: \(module.name)")
                    } else {
                        viewModel.cancelInstall(module: module)
                    }
                }
            )
        }
    }



    // MARK: - Subviews

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.organizedModules.keys.sorted(), id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                    }
                    .clipShape(Capsule())
                    .buttonStyle(.glass)
                    .tint(selectedCategory == category ? .accentColor.opacity(0.7) : nil)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 15) // Added space from progress bar
            .padding(.bottom, 12)
        }
        .background(Color.clear) // Transparent background
    }

    private var sourceToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    Button {
                        viewModel.fetchModules(wrapper: wrapper, source: viewModel.selectedSource)
                    } label: {
                        Label("Refresh Catalog", systemImage: "arrow.clockwise")
                    }
                }
                Section("Repository Source") {
                    Picker("Change Source", selection: $viewModel.selectedSource) {
                        ForEach(viewModel.availableSources, id: \.name) { source in
                            Text(source.name).tag(source.name)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
            }
            .menuIndicator(.hidden)
            .onChange(of: viewModel.selectedSource) { val in
                viewModel.fetchModules(wrapper: wrapper, source: val)
            }
        }
    }

    private var mainCatalogContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            let languages = viewModel.organizedModules[selectedCategory] ?? [:]
            
            if languages.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                ForEach(languages.keys.sorted(), id: \.self) { langCode in
                    let modules = languages[langCode] ?? []
                    LanguageSection(
                        langCode: langCode,
                        count: modules.count,
                        modules: modules,
                        bookViewBuilder: bookViewBuilder,
                        isExpanded: expandedLanguages.contains(langCode),
                        toggle: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedLanguages.contains(langCode) {
                                    expandedLanguages.remove(langCode)
                                } else {
                                    expandedLanguages.insert(langCode)
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var searchResultsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. Results from current source
            let localResults = viewModel.organizedModules.values.flatMap { $0.values }.flatMap { $0 }
            
            if !localResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("From \(viewModel.selectedSource)")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    ForEach(localResults, id: \.name) { module in
                        bookViewBuilder(module)
                            .padding(.horizontal, 20)
                    }
                }
            }
            
            // 2. Global Search Button
            if !viewModel.isSearchingGlobally {
                Button {
                    viewModel.searchAllSources(wrapper: wrapper)
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text("Search in all repositories")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching other repositories...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
            
            // 3. Results from other sources
            ForEach(viewModel.globalSearchResults.keys.sorted(), id: \.self) { sourceName in
                let modules = viewModel.globalSearchResults[sourceName] ?? []
                VStack(alignment: .leading, spacing: 12) {
                    Text("From \(sourceName)")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    ForEach(modules, id: \.name) { module in
                        bookViewBuilder(module)
                            .padding(.horizontal, 20)
                    }
                }
            }
            
            if localResults.isEmpty && viewModel.globalSearchResults.isEmpty && !viewModel.isSearchingGlobally {
                emptyState
            }
        }
        .padding(.vertical, 20)
    }

    
    private var emptyState: some View {
        ContentUnavailableView("No Modules Found", systemImage: "magnifyingglass")
            .padding(.top, 100)
    }
}
// MARK: - Collapsible Language Section Component


#Preview {
    // Create a dummy wrapper
    let mockWrapper = SwordEngineWrapper()
    
    return StoreView()
        .environmentObject(mockWrapper)
}


#Preview{
    
    
}
