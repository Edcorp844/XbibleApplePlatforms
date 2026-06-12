import SwiftUI
import XbibleEngine

struct LanguageSection: View {

    // MARK: - Properties

    let langCode: String
    let count: Int
    let modules: [XbibleEngine.SwordModule]
    let bookViewBuilder: (XbibleEngine.SwordModule) -> AnyView
    let isExpanded: Bool
    let toggle: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerButton
            
            if isExpanded {
                modulesScrollView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
                .padding(.horizontal, 20)
                .opacity(0.3)
        }
    }

    // MARK: - Subviews

    private var headerButton: some View {
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
    }

    private var modulesScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 20) {
                ForEach(modules, id: \.name) { module in
                    bookViewBuilder(module)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
