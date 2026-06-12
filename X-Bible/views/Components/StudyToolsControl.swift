//
//  StudyToolsControl.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//


import SwiftUI

struct StudyToolsControl<T: Hashable & Equatable>: View {
    @Binding var selection: T
    let items: [T]
    let title: (T) -> String
    
    @Namespace private var activeSegmentNamespace
    @State private var hoveredItem: T? = nil
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                let isHovered = hoveredItem == item
                
                Text(title(item))
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .lineLimit(1)
                    .background(
                        ZStack {
                            // Selected Background Pill
                            if isSelected {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                #if os(macOs)
                                    .fill(Color(nsColor: .controlAccentColor))
#else
                                    .fill(Color.primary)
                                #endif
                                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "activeSegment", in: activeSegmentNamespace)
                            }
                            // Hover State Background
                            else if isHovered {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            }
                        }
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onHover { inside in
                        withAnimation(.easeOut(duration: 0.15)) {
                            hoveredItem = inside ? item : nil
                        }
                    }
                    .onTapGesture {
                        if !isSelected {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                selection = item
                            }
                        }
                    }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
            #if os(macOs)
                .fill(Color(nsColor: .controlBackgroundColor))
            #endif
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }
}

//// MARK: - Preview Simulator
//#Preview {
//    @Previewable @State var currentTab: String = "Dictionary"
//    
//    VStack {
//        StudyToolsControl(
//            selection: $currentTab,
//            items: ["Dictionary", "Lexicon", "Commentary"],
//            title: { $0 }
//        )
//    }
//    .padding()
//    .frame(width: 300)
//}
