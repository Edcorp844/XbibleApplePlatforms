import SwiftUI
import XbibleEngine

struct TimelineItemView: View {
    let event: Event
    let periodColor: Color
    let width: CGFloat
    var onSelect: (Event) -> Void

    var body: some View {
        Button {
            onSelect(event)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimelineUtils.rangeLabel(start: event.start, end: event.end))
                        .font(.system(size: 9, weight: .bold).monospaced())
                        .foregroundColor(periodColor)
                        .lineLimit(1)

                    Text(event.title)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }

                Spacer(minLength: 0)

                if width > 100,
                   let imageUrlString = event.image,
                   let url = URL(string: imageUrlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.1)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(width: max(width, 20), alignment: .leading)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 8,
                    bottomTrailingRadius: 8,
                    topTrailingRadius: 8
                )
                #if os(macOS)
                .fill(Color(NSColor.windowBackgroundColor))
                #else
                .fill(.clear)
                #endif
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 8,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(periodColor)
                .frame(width: 4),
                alignment: .leading
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 8,
                    bottomTrailingRadius: 8,
                    topTrailingRadius: 8
                )
                .stroke(periodColor, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}
