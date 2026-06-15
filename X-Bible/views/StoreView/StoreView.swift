import SwiftUI
import XbibleEngine
import SwiftData

struct StoreView: View {

    // MARK: - Environment

    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var viewModel = StoreViewModel()
    @State private var selectedCategory: String = "Biblical Texts"
    @State private var expandedLanguages: Set<String> = []

    // MARK: - Body
    @State private var activeTab: CategoryTab = .allCategories
    var body: some View {
        NavigationStack{
            ScrollView(.vertical){
                CategoryTabBar(selection: $activeTab)
                    .padding(.horizontal, 16)
                mainCatalogContent
            }
            .navigationTitle("Store")
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext, wrapper: wrapper)
        }
        .onChange(of: viewModel.allRemoteModules) { oldValue, newValue in
            updateSelectedCategory()
        }
        // Syncs your layout state dynamically when tapping tabs without changing your layout
        .onChange(of: activeTab) { oldValue, newValue in
            if newValue != .allCategories {
                withAnimation { selectedCategory = newValue.title }
            }
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
                        ? Color.accentColor
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
        
        // Inverse update the custom tab bar selection token to keep bindings aligned
        if let currentTabMatch = CategoryTab.allCases.first(where: { $0.title == selectedCategory }) {
            activeTab = currentTabMatch
        }
    }
}



protocol CategoryTabItem: CaseIterable, Hashable, Equatable{
    var symbol: String{ get }
    var title: String { get }
    var activeTint: Color { get }
    var activeBackground: Color { get }
}


enum CategoryTab: CategoryTabItem {
    case allCategories
    case bibleTexts
    case commentaries
    case glossaries
    case books
    case maps
    
    // Dynamically matched string representations aligning precisely to FFI payloads
    var title: String {
        return switch self{
        case .allCategories: "All"
        case .bibleTexts: "Biblical Texts"
        case .commentaries: "Commentaries"
        case .glossaries: "Glossaries"
        case .books: "General Books"
        case .maps: "Maps"
        }
    }
    
    var symbol: String {
        return switch self{
        case .allCategories: "person.fill"
        case .bibleTexts: "cart.fill"
        case .commentaries: "text.bubble.fill"
        case .glossaries: "person.fill"
        case .books: "cart.fill"
        case .maps: "cart.fill"
        }
    }
    
    var activeTint: Color {
        return .white
    }
    
    var activeBackground: Color {
        return switch self{
        case .allCategories: .accent
        case .bibleTexts: .green
        case .commentaries: .cyan
        case .glossaries: .green
        case .books: .orange
        case .maps: .indigo
        }
    }
}

struct CategoryTabBar<Tab: CategoryTabItem> : View {
    var spacing: CGFloat = 8
    var trailingVisibility: CGFloat = 25
    var isGestureEnabled: Bool = false
    @Binding var selection: Tab
    @State private var tabTitleSizes: [Tab: CGSize] = [:]
    @State private var previousTab: Tab?
    var body: some View {
        let isLastTabActive: Bool = selection == allTabs.last
        GeometryReader{
            let containerSize = $0.size
            let activeTitleWidth: CGFloat = tabTitleSizes[selection]?.width ?? 0
            
            let activeWidth: CGFloat = activeTitleWidth + 60 + 6
            
            let removeCount : Int = isLastTabActive ? 1 : 2
            let spacingValue: CGFloat = CGFloat(allTabs.count - removeCount) * spacing
            let inactiveWidth: CGFloat = (containerSize.width - activeWidth - spacing) /  CGFloat(allTabs.count - removeCount)
            
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(allTabs, id: \.title) { tab in
                        TabItemView(tab, inactiveWidth: inactiveWidth)
                    }
                }
            }
        }
        .padding(.trailing, isLastTabActive ? 0 : trailingVisibility)
        .frame(height: 38)
        .contentShape(.rect)
        .animation(animation, value: selection)
        .gesture(toggleGesture, isEnabled: isGestureEnabled)
        .onAppear{
            guard previousTab == nil else {return}
            previousTab = selection
        }.onChange(of: selection){ oldValue, newValue in
            previousTab = oldValue
        }
    }
    
    @ViewBuilder
    func TabItemView(_ tab: Tab, inactiveWidth: CGFloat) -> some View{
        let isActive = selection == tab
        HStack(spacing: 6) {
            Image(systemName: tab.symbol)
                .font(.body)
                .frame(width: 20)
            
            Text(tab.title)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .onGeometryChange(for: CGSize.self){
                    $0.size
                } action : { newValue in
                    tabTitleSizes[tab] = newValue
                }
                .frame( width: isActive ? nil : 0, alignment: isActive ? .leading : .center)
                .opacity(isActive ? 1 : 0)
        }
        .foregroundStyle(isActive ? tab.activeTint : .gray)
        .padding(.horizontal, isActive ? 20: 20)
        .frame(width: isActive ? nil : 70)
        .frame(maxHeight: .infinity)
        .background{
            ZStack {
                Capsule()
                    .fill(.fill)
                    .opacity(isActive ? 0 : 1)
                Capsule()
                    .fill(tab.activeBackground)
                    .opacity(isActive ? 1: 0)
                
            }
        }
        .clipShape(.capsule)
        .contentShape(.capsule)
        .geometryGroup()
        
        .onTapGesture {
            if let lastTab = allTabs.last, let previousTab , selection == tab {
                if selection == lastTab {
                    selection = previousTab
                } else {
                    selection = lastTab
                }
            }
             selection = tab
            
        }
    }
    
    var toggleGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded{
                value in
                let xTransilation = value.translation.width
                guard abs(xTransilation) > 40 else { return }
                if xTransilation > 0 {
                    guard let previousTab else {return}
                    selection = previousTab
                } else {
                    guard let lastTab = allTabs.last else {return}
                    selection = lastTab
                }
            }
    }
    
    var animation: Animation {
        .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)
    }
    
    var allTabs: [Tab.AllCases.Element] {
        Array(Tab.allCases)
    }
}


struct StoreViewNew: View {
    @State private var activeTab: CategoryTab = .allCategories
    var body: some View {
        NavigationStack{
            ScrollView(.vertical){
                CategoryTabBar(selection: $activeTab)
            }
            .safeAreaPadding(15)
            .navigationTitle("Store")
        }
    }
}

#Preview {
    Group {
        StoreViewNew()
    }
}
