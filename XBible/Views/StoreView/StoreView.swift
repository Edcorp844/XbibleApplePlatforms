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
                VStack(alignment: .leading, spacing: 2) {
                    let languages = viewModel.organizedModules[selectedCategory] ?? [:]
                    
                    if languages.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else {
                        ForEach(languages.keys.sorted(), id: \.self) { langCode in
                            let modules = languages[langCode] ?? []
                            LanguageSection(
                                viewModel: viewModel,
                                langCode: langCode,
                                count: modules.count,
                                modules: modules,
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
        }
        .navigationTitle("Store")
        .navigationSubtitle(viewModel.selectedSource)
        .onAppear { viewModel.loadStore(wrapper: wrapper) }
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

    private var emptyState: some View {
        ContentUnavailableView("No Modules", systemImage: "magnifyingglass")
            .padding(.top, 100)
    }
}
// MARK: - Collapsible Language Section Component

struct LanguageSection: View {
    @ObservedObject var viewModel: StoreViewModel
    let langCode: String
    let count: Int
    let modules: [XbibleEngine.SwordModule]
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: toggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Locale.current.localizedString(forLanguageCode: langCode) ?? langCode.uppercased())
                            .font(.headline)
                        Text("\(count) \(count == 1 ? "module" : "modules")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0)) // Animated Chevron
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Collapsible Content
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        ForEach(modules, id: \.name) { module in
                            PhysicalBookView(module: module, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider()
                .padding(.horizontal, 20)
                .opacity(0.3)
        }
    }
}

#Preview {
    // Create a dummy wrapper
    let mockWrapper = SwordEngineWrapper()
    
    return StoreView()
        .environmentObject(mockWrapper)
}


#Preview{
    
    
}
