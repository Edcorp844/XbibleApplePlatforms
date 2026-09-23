//
//  PopoverButton.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftUI


// MARK: - Popover Button

struct PopoverButton<Content: View>: View {
    let label: String
    let title: String
    @Binding var isPresented: Bool
    let bypassPopover: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: {
            if bypassPopover {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPresented.toggle()
                }
            } else {
                isPresented.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Text(label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.5)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            
#if os(macOS)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
#else
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .cornerRadius(16)
#endif
        }
        .buttonStyle(.plain)
        .modifier(PopoverPresenterModifier(
            isPresented: $isPresented,
            bypass: bypassPopover,
            title: title,
            content: content
        ))
    }
}

struct PopoverPresenterModifier<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let bypass: Bool
    let title: String
    let content: () -> PopoverContent
    
    func body(content: Content) -> some View {
        if bypass {
            content
        } else {
            content.popover(isPresented: $isPresented, arrowEdge: .bottom) {
#if os(iOS)
                NavigationStack {
                    self.content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 16)
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(action: { isPresented = false }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                }
                .presentationCompactAdaptation(.sheet)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
#else
                self.content()
#endif
            }
        }
    }
}

