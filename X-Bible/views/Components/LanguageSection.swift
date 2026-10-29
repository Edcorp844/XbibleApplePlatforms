import SwiftUI
import XbibleEngine

struct LanguageSection: View {

    // MARK: - Properties

    let langCode: String
    let count: Int
    let modules: [XbibleEngine.SwordModule]
    let bookViewBuilder: (XbibleEngine.SwordModule) -> AnyView

    @State private var isExpanded = true

    // MARK: - Body

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            modulesScrollView
                .padding(.top, 4)
                .padding(.bottom, 12)
        } label: {
            headerLabel
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .tint(.secondary)
    }

    // MARK: - Subviews

    private var headerLabel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Locale.current.localizedString(forLanguageCode: langCode) ?? langCode.uppercased())
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(count) \(count == 1 ? "module" : "modules")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var modulesScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(modules, id: \.compoundId) { module in
                    bookViewBuilder(module)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

extension XbibleEngine.SwordModule {
    var compoundId: String {
        "\(source)-\(name)"
    }
}
