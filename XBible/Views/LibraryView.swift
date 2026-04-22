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
    @State private var selectedCategory: String = "Biblical Texts"
    @State private var expandedLanguages: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Loading library...")
                    .padding()
            }
            
            // Only show category picker for "All Library"
            if category == .all {
                categoryPicker
            }
            
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let languages = viewModel.organizedModules[selectedCategory] ?? [:]
                    
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
                                }
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
            let organized = viewModel.organizedModules
            
            if category == .all {
                // For "All Library", auto-select first category
                if let first = organized.keys.sorted().first {
                    selectedCategory = first
                }
            } else {
                // For specific categories, show all modules directly
                selectedCategory = category.title
            }
            
            // Expand everything by default
            let allLangCodes = organized.values.flatMap { $0.keys }
            expandedLanguages = Set(allLangCodes)
        }
    }
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Only show categories that actually have modules
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
            .padding(.top, 15)
            .padding(.bottom, 12)
        }
        .background(Color.clear)
    }
    
    private var emptyState: some View {
        ContentUnavailableView("No Installed Modules", systemImage: "books.vertical")
            .padding(.top, 100)
    }
}

// MARK: - Collapsible Language Section Component

struct LibLanguageSection: View {
    let modules: [XbibleEngine.SwordModule]
    let langCode: String
    let count: Int
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
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
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
                            LibraryBookView(module: module)
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

// MARK: - Library Book View Component

struct LibraryBookView: View {
    let module: XbibleEngine.SwordModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Physical Book Cover
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 12
                )
                .fill(generatePersistentColor(for: "\(module.name)\(module.description)"))
                
                // Book styling (same as store)
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 12
                )
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.35), location: 0),
                            .init(color: .white.opacity(0.15), location: 0.05),
                            .init(color: .clear, location: 0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 3)
                    Spacer()
                }
                
                VStack(spacing: 0) {
                    Text(module.description)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        .lineLimit(8)
                        .minimumScaleFactor(0.7)
                    
                    Spacer()
                    
                    Text("Version \(module.version)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 24)
            }
            .frame(width: 150, height: 210)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 5, y: 10)
            
            // Bottom Info Bar
            HStack(spacing: 8) {
                VStack(alignment: .leading) {
                    Text(module.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text(module.description)
                        .lineLimit(1)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Open button for installed modules
                Button {
                    // TODO: Open module in study view
                    print("Open \(module.name)")
                } label: {
                    Text("Open")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1.2))
            }
            .frame(width: 150)
            .offset(y: 4)
        }
        .padding(10)
    }
    
    func generatePersistentColor(for input: String) -> Color {
        let hash = input.hashValue
        let hue = Double(abs(hash % 1000)) / 1000.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.45)
    }
}
