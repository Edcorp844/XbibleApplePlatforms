//
//  AdaptivePresentationModifier.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/26/26.
//

import SwiftUI

/// Presents `content` adaptively:
///   • iPhone (compact width) → full-height sheet
///   • iPad   (regular width) → popover anchored to the source
///   • macOS                  → popover
///
/// On iOS the presented content is wrapped in a `NavigationStack` and a
/// trailing toolbar close button so the user can dismiss it from the sheet
/// or popover chrome.
struct AdaptivePresentationModifier<Presented: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String?
    let detents: Set<PresentationDetent>
    let preferredPopoverEdge: Edge
    @ViewBuilder let presented: () -> Presented

    @Environment(\.horizontalSizeClass) private var hSize

    private var useBottomSheet: Bool {
        #if os(iOS)
        return hSize == .compact
        #else
        return false
        #endif
    }

    func body(content: Content) -> some View {
        content
            .popover(
                isPresented: $isPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: preferredPopoverEdge
            ) {
                if useBottomSheet {
                    // iPhone — full-height sheet, no grabber.
                    wrapped
                        .presentationCompactAdaptation(.sheet)
                        .presentationDetents([.large])
                } else {
                    // iPad / macOS — regular popover.
                    wrapped
                        .presentationCompactAdaptation(.popover)
                        .frame(minWidth: 320, idealWidth: 380, minHeight: 260)
                }
            }
    }

    /// Wraps the presented content in a NavigationStack on iOS so we can
    /// attach a title and a close button in the toolbar. On macOS the
    /// content is presented as-is (popovers there don't need a chrome bar).
    @ViewBuilder
    private var wrapped: some View {
        #if os(iOS)
        NavigationStack {
            presented()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(title ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                }
        }
        #else
        presented()
        #endif
    }
}

extension View {
    /// Adaptive presentation: full-height sheet on iPhone, popover on iPad/macOS.
    func adaptivePresentation<Presented: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        detents: Set<PresentationDetent> = [.large],
        popoverEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> Presented
    ) -> some View {
        modifier(AdaptivePresentationModifier(
            isPresented: isPresented,
            title: title,
            detents: detents,
            preferredPopoverEdge: popoverEdge,
            presented: content
        ))
    }
}
