//
//  SplitDivider.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI

struct SplitDivider: View {
    @Binding var detailWidth: CGFloat
    @State private var dragStartWidth: CGFloat = 350
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 8)
            Rectangle()
                .fill(isHovering ? Color.accentColor : Color.primary.opacity(0.15))
                .frame(width: 2)
        }
        .frame(width: 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            #if os(macOS)
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if value.startLocation == value.location {
                        dragStartWidth = detailWidth
                    }
                    detailWidth = max(250, min(800, dragStartWidth - value.translation.width))
                }
        )
    }
}
