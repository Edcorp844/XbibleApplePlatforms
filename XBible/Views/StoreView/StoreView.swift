import SwiftUI
import XbibleEngine

struct StoreView: View {

    // MARK: - Environment

    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var viewModel = StoreViewModel()
    @State private var selectedCategory: String = "Biblical Texts"
    @State private var expandedLanguages: Set<String> = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            loadingBar
            categoryPicker

            ScrollView {
                mainCatalogContent
            }
        }
        .navigationTitle("Combined Store")
        .searchable(text: $viewModel.searchText, prompt: "Search all repositories...")
        .onAppear {
            viewModel.setup(modelContext: modelContext, wrapper: wrapper)
        }
        .onChange(of: viewModel.allRemoteModules) { oldValue, newValue in
            updateSelectedCategory()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var loadingBar: some View {
        if viewModel.isLoading {
            ProgressView()
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .padding(.bottom, -4)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.organizedModules.keys.sorted(), id: \.self) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
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
                        bookViewBuilder: { AnyView(bookView(for: $0)) },
                        isExpanded: expandedLanguages.contains(langCode),
                        toggle: { toggleLanguage(langCode) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView("No Modules", systemImage: "magnifyingglass")
            .padding(.top, 100)
    }

    // MARK: - Helpers

    private func categoryButton(for category: String) -> some View {
        Button {
            withAnimation { selectedCategory = category }
        } label: {
            Text(category)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selectedCategory == category
                        ? Color.accentColor.opacity(0.15)
                        : Color.primary.opacity(0.05)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Reads status fresh from viewModel on every render so the card
    /// always reflects live state (pending, installing, installed, etc.)
    private func bookView(for module: XbibleEngine.SwordModule) -> some View {
        let status = viewModel.installationStates[module.name] ?? .idle

        return BookCardView(
            module: module,
            status: status,
            showActionButton: true,
            action: {
                // Re-read at tap time — never act on the captured status
                let currentStatus = viewModel.installationStates[module.name] ?? .idle
                handleAction(for: module, status: currentStatus)
            }
        )
        .overlay(alignment: .topTrailing) {
            sourceLabel(for: module.source)
        }
        // Forces card to re-render when its installation status changes
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

    /// Stable string ID for diffing status changes via `.id()`
    private func statusID(_ status: InstallationStatus) -> String {
        switch status {
        case .idle:               return "idle"
        case .cancelled:          return "cancelled"
        case .installed:          return "installed"
        case .pending:            return "pending"
        case .installing:         return "installing"
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
        let organized = viewModel.organizedModules
        if selectedCategory.isEmpty || organized[selectedCategory] == nil {
            selectedCategory = organized.keys.sorted().first ?? "Biblical Texts"
        }
        if let categoryLanguages = organized[selectedCategory] {
            expandedLanguages = Set(categoryLanguages.keys)
        } else {
            expandedLanguages = []
        }
    }
}
