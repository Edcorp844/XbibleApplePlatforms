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
    @StateObject private var viewModel = LibraryViewModel()
    
    let category: SidebarItem
    @State private var expandedLanguages: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Loading library...")
                    .padding()
            }
            
            
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                        let languages = viewModel.modulesByLanguage
                        
                        if languages.isEmpty && !viewModel.isLoading {
                            emptyState
                        } else {
                            ForEach(languages.keys.sorted(), id: \.self) { langCode in
                                let modules = languages[langCode] ?? []
                                LibLanguageSection(
                                    modules: modules,
                                    langCode: langCode,
                                    count: modules.count,
                                    isExpanded: expandedLanguages.contains(langCode),
                                    toggle: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            if expandedLanguages.contains(langCode) {
                                                expandedLanguages.remove(langCode)
                                            } else {
                                                expandedLanguages.insert(langCode)
                                            }
                                        }
                                    },
                                    categoryName: category.title
                                )
                            
                        }
                    }
                }
                .padding(.vertical, 20)
            }
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
        .onChange(of: wrapper.engineVersion) { _ in
            viewModel.loadInstalledModules(wrapper: wrapper, category: category)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.refreshModules(wrapper: wrapper, category: category)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onChange(of: viewModel.installedModules) { _ in
            let languages = viewModel.modulesByLanguage
            
            // Expand everything by default
            expandedLanguages = Set(languages.keys)
            
        }
    }
    
    
    private var emptyState: some View {
        ContentUnavailableView("No Installed Modules", systemImage: "books.vertical")
            .padding(.top, 100)
    }
}


// MARK: - Library Language Section Component

struct LibLanguageSection: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    let modules: [XbibleEngine.SwordModule]
    let langCode: String
    let count: Int
    let isExpanded: Bool
    let toggle: () -> Void
    let categoryName: String

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
                            BookCardView(
                                module: module,
                                status: .installed,
                                showActionButton: false,
                                action: {
                                    wrapper.openModuleInStudy(module)
                                },
                                categoryName: categoryName,
                                
                                menuAction: {
                                    // TODO: Show update menu
                                    print("Menu for \(module.name)")
                                    
                                }
                            )
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
