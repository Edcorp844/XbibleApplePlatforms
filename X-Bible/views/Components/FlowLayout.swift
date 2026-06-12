//
//  FlowLayout.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//
import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(at: .zero, in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = layout(at: bounds.origin, in: bounds.width, subviews: subviews, place: true)
    }
    private func layout(at origin: CGPoint, in maxWidth: CGFloat, subviews: Subviews, place: Bool = false) -> (size: CGSize, lastY: CGFloat) {
        var x = origin.x, y = origin.y, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > origin.x + maxWidth {
                x = origin.x
                y += rowHeight + spacing
                rowHeight = 0
            }
            if place { subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified) }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - origin.x)
        }
        return (CGSize(width: width, height: y + rowHeight - origin.y), y + rowHeight)
    }
}
