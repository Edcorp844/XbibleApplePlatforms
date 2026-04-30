import SwiftUI


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
            HStack(alignment: .center, spacing: 6) {
                // 1. Text Content Column
                VStack(alignment: .leading, spacing: 0) {
                    Text(TimelineUtils.calculateLabel(start: event.start, end: event.end))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(sectionColor)
                        .lineLimit(1)

                    Text(event.title)
                        .font(.system(size: event.type == .period ? 11 : 10, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                
                Spacer(minLength: 0)

                // 2. Small Image (Conditional based on bar width)
                // Bible Strong style usually hides images in the timeline bar if too narrow
                if width > 140, let imageUrlString = event.image, let url = URL(string: imageUrlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.1)
                        }
                    }
                    .frame(width: 24, height: 24) // Smaller for the 30px row height
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(.vertical, 2)
            .padding(.leading, 12) // Space for accent bar
            .padding(.trailing, 6)
            // Use the calculated width from the mapRange logic
            .frame(width: width, height: 34, alignment: .leading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 6)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                // Left Accent Bar
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .fill(sectionColor)
                    .frame(width: 4),
                alignment: .leading
            )
            .overlay(
                // Subtle Border
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 6)
                    .stroke(sectionColor.opacity(0.3), lineWidth: event.type == .period ? 1.5 : 0.5)
            )
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
