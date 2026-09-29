//
//  FlowLayout.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI

struct FlowLayout: Layout {
    /// Horizontal gap between items on the same row (word spacing).
    var spacing: CGFloat = 10

    /// Vertical gap between wrapped rows (line spacing).
    var lineSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        let result = layout(at: .zero, in: maxWidth, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        _ = layout(at: bounds.origin, in: bounds.width, subviews: subviews, place: true)
    }

    private func layout(
        at origin: CGPoint,
        in maxWidth: CGFloat,
        subviews: Subviews,
        place: Bool = false
    ) -> (size: CGSize, lastY: CGFloat) {
        var x = origin.x
        var y = origin.y
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = origin.x

        let limit = origin.x + maxWidth

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            // Wrap if this item would overflow the row AND it isn't the
            // first item on the current row (nothing to wrap if the row
            // is empty — an oversized item just overflows, which is the
            // correct behavior and mirrors symmetrically under RTL).
            if x > origin.x, x + size.width > limit {
                x = origin.x
                y += rowHeight + lineSpacing   // gap between wrapped rows
                rowHeight = 0
            }

            if place {
                subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: .unspecified
                )
            }

            x += size.width

            if index < subviews.count - 1 {
                x += spacing                    // horizontal gap between words
            }

            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - (index < subviews.count - 1 ? spacing : 0))
        }

        return (
            CGSize(width: maxX - origin.x, height: y + rowHeight - origin.y),
            y + rowHeight
        )
    }
}
