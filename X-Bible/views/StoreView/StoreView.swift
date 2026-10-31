//
//  StoreView.swift
//  XBible
//

import SwiftUI
import XbibleEngine
import SwiftData

struct StoreView: View {

    // MARK: - Environment
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var viewModel: StoreViewModel

    // MARK: - State
    @State private var showSourcePicker: Bool = false
    @State private var moduleToShowDetails: XbibleEngine.SwordModule? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            catalogContent
                .navigationTitle("Store")
                .searchable(
                    text: $viewModel.searchText,
                    placement: horizontalSizeClass == .regular ? .toolbar : .automatic,
                    prompt: "Search ..."
                )
                .refreshable {
                    await refresh()
                }
                .toolbar {
                    ToolbarItem(placement: {
                        #if os(macOS)
                        .primaryAction
                        #else
                        .topBarTrailing
                        #endif
                    }()) {
                        NavigationLink {
                            AudioStoreView()
                        } label: {
                            Label("Audio Store", systemImage: "headphones")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        sourcePickerButton
                    }
                }
                .onAppear {
                    viewModel.setup(modelContext: modelContext, wrapper: wrapper)
                }
        }
    }

    // MARK: - Catalog

    private var catalogContent: some View {
        ScrollView(.vertical) {
            mainCatalogContent
                .padding(.top, 8)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaInset(edge: .top, spacing: 0) {
            DynamicCategoryTabBar(
                categories: viewModel.availableCategories,
                selection: Binding(
                    get: { viewModel.selectedCategory },
                    set: { viewModel.setCategory($0) }
                )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var mainCatalogContent: some View {
        if viewModel.isLoading && viewModel.filteredLanguages.isEmpty {
            ProgressView("Loading modules…")
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else if viewModel.filteredLanguages.isEmpty {
            emptyState
        } else {
            languageList
        }
    }

    private var languageList: some View {
        let languages = viewModel.filteredLanguages
        let keys = languages.keys.sorted()

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(keys, id: \.self) { langCode in
                let modules = languages[langCode] ?? []
                LanguageSection(
                    langCode: langCode,
                    count: modules.count,
                    modules: modules,
                    bookViewBuilder: { module in
                        AnyView(bookView(for: module))
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.15), value: viewModel.searchText)
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
                ProgressView().frame(maxWidth: .infinity).padding()
            } else {
                ForEach(viewModel.availableSources, id: \.name) { source in
                    sourceRow(source)
                }
            }
        }
        #if os(macOS)
        .padding(12).frame(minWidth: 220)
        #else
        .padding(.vertical, 8).frame(maxWidth: .infinity)
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
            if viewModel.searchText.isEmpty {
                ContentUnavailableView("No Modules", systemImage: "magnifyingglass")
            } else {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No modules match “\(viewModel.searchText)”")
                )
            }
        }
        .padding(.top, 100)
    }

    private func bookView(for module: XbibleEngine.SwordModule) -> some View {
        let status = viewModel.status(for: module)

        return BookCardView(
            module: module,
            status: status,
            showActionButton: true,
            action: {
                handleAction(for: module, status: viewModel.status(for: module))
            }
        )
        .overlay(alignment: .topTrailing) {
            sourceLabel(for: module.source)
        }
        .id("\(module.name)-\(statusID(status))")
        .contextMenu {
            Button {
                moduleToShowDetails = module
            } label: {
                Label("Show Details", systemImage: "info.circle")
            }

            Divider()

            switch status {
            case .idle, .cancelled:
                Button {
                    viewModel.install(module: module, wrapper: wrapper)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            case .installed:
                Button {
                    print("Open module: \(module.name)")
                } label: {
                    Label("Open", systemImage: "book")
                }
            case .pending, .installing:
                Button(role: .destructive) {
                    viewModel.cancelInstall(moduleName: module.name)
                } label: {
                    Label("Cancel Download", systemImage: "xmark.circle")
                }
            }
        }
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
        case .idle: return "idle"
        case .cancelled: return "cancelled"
        case .installed: return "installed"
        case .pending: return "pending"
        case .installing: return "installing"
        }
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

// MARK: - Dynamic Tab Bar (unchanged)

struct DynamicCategoryTabBar: View {
    let categories: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories, id: \.self) { category in
                    tabButton(for: category)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 10).onChanged { _ in }
        )
    }

    @ViewBuilder
    private func tabButton(for category: String) -> some View {
        let isActive = selection == category

        Button {
            withAnimation(.interpolatingSpring(duration: 0.28, bounce: 0)) {
                selection = category
            }
        } label: {
            Text(category)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundStyle(isActive ? .white : .primary)
                .padding(.horizontal, isActive ? 12 : 10)
                .padding(.vertical, 5)
        }
        .background {
            Capsule()
                .fill(isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }
}
