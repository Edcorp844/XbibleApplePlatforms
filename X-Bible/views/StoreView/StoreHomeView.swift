//
//  StoreHomeView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 10/31/26.
//


//
//  StoreHomeView.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct StoreHomeView: View {
    @ObservedObject var viewModel: AudioStoreViewModel
    @Binding var path: [StoreRoute]

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                browseRow
                CollectionsGroup(collections: viewModel.collections)
                filterBar
                moduleGrid
            }
            .padding(20)
        }
        .navigationTitle("Audio Store")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .searchable(text: $viewModel.searchText, prompt: "Search modules, narrators")
        .refreshable { await viewModel.loadCatalog() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Listen to the Word")
                .font(.largeTitle.bold())
            Text("\(viewModel.availableModules.count) modules across \(viewModel.languages.count) language\(viewModel.languages.count == 1 ? "" : "s")")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var browseRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                BrowseTile(
                    title: "Languages",
                    subtitle: "\(viewModel.languages.count)",
                    systemImage: "globe"
                ) {
                    if let first = viewModel.languages.first {
                        path.append(.language(first))
                    }
                }

                BrowseTile(
                    title: "Narrators",
                    subtitle: "\(viewModel.narrators.count)",
                    systemImage: "person.wave.2"
                ) {
                    if let first = viewModel.narrators.first {
                        path.append(.narrator(first))
                    }
                }

                BrowseTile(
                    title: "Installed",
                    subtitle: "\(viewModel.availableModules.filter(\.isInstalled).count)",
                    systemImage: "checkmark.seal"
                ) {
                    viewModel.selectedFilter = .installed
                }
            }
        }
    }

    private var filterBar: some View {
        Picker("Filter", selection: $viewModel.selectedFilter) {
            ForEach(ModuleFilter.allCases) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var moduleGrid: some View {
        if viewModel.isEmptyState {
            ContentUnavailableView {
                Label("No Modules", systemImage: "square.grid.2x2")
            } description: {
                Text(viewModel.searchText.isEmpty
                     ? "The catalog is empty."
                     : "No modules match “\(viewModel.searchText)”.")
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.filteredModules, id: \.uniqueId) { module in
                    NavigationLink(value: StoreRoute.module(module)) {
                        ModuleCard(module: module, viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BrowseTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 140, alignment: .leading)
            .padding(14)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
