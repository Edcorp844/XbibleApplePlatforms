//
//  FlowLayout.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat
    /// Explicit direction. Prefer setting this (or rely on the environment).
    var layoutDirection: LayoutDirection = .leftToRight

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        return arrange(maxWidth: maxWidth, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(maxWidth: bounds.width, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: .unspecified
            )
        }
    }

    // MARK: - Arrangement

    private struct Arrangement {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> Arrangement {
        guard !subviews.isEmpty else {
            return Arrangement(size: .zero, positions: [])
        }

        let isRTL = layoutDirection == .rightToLeft

        // Reverse so the logical first item lands on the right in RTL.
        let ordered = isRTL ? Array(subviews.reversed()) : Array(subviews)

        var positions = Array(repeating: CGPoint.zero, count: subviews.count)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for (i, subview) in ordered.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            // Wrap if this item would exceed the available width
            // (and we already have something on the current row).
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            // Map back to the original subview index
            let originalIndex = isRTL ? (subviews.count - 1 - i) : i
            positions[originalIndex] = CGPoint(x: x, y: y)

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x)
        }

        // Remove the trailing spacing that was added after the last item
        if maxRowWidth > 0 {
            maxRowWidth -= spacing
        }

        let totalHeight = y + rowHeight
        return Arrangement(
            size: CGSize(width: maxRowWidth, height: totalHeight),
            positions: positions
        )
    }
}
