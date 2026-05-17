import SwiftUI


import SwiftUI

import SwiftUI

struct TimelineItemView: View {
    let event: TimelineEvent
    let sectionColor: Color
    let width: CGFloat
    var onSelect: (TimelineEvent) -> Void

    var body: some View {
        Button {
            onSelect(event)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimelineUtils.calculateLabel(start: event.start, end: event.end))
                        .font(.system(size: 9, weight: .bold).monospaced())
                        .foregroundColor(sectionColor)
                        .lineLimit(1)

                    Text(event.title)
                        .font(.system(size: event.type == .period ? 12 : 10, weight: .bold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                
                Spacer(minLength: 0)

                // Image (scales with width)
                if width > 100, let imageUrlString = event.image, let url = URL(string: imageUrlString) {
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
                // Corrected Name: UnevenRoundedRectangle
                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                // Accent Bar (Matches left side curves)
                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .fill(sectionColor)
                    .frame(width: 4),
                alignment: .leading
            )
            .overlay(
                // Border
                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 8)
                    .stroke(sectionColor, lineWidth: event.type == .period ? 2 : 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// Ensure this struct is in your file if you are targeting versions below macOS 14
// or if the compiler doesn't recognize the native version.
struct UnevenRoundedRectangle: Shape {
    var topLeadingRadius: CGFloat = 0
    var bottomLeadingRadius: CGFloat = 0
    var bottomTrailingRadius: CGFloat = 0
    var topTrailingRadius: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height

        let tr = min(min(topTrailingRadius, h/2), w/2)
        let tl = min(min(topLeadingRadius, h/2), w/2)
        let bl = min(min(bottomLeadingRadius, h/2), w/2)
        let br = min(min(bottomTrailingRadius, h/2), w/2)

        path.move(to: CGPoint(x: w / 2.0, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr,
                    startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br,
                    startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl,
                    startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl,
                    startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
