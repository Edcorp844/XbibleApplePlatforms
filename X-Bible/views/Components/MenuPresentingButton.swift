//
//  MenuPresentingButton.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/26/26.
//


//
//  MenuPresentingButton.swift
//  XBible
//
//  Created by Zoe Brooklyn on 9/26/26.
//

import SwiftUI

/// A menu item that presents adaptive content when tapped.
/// Use inside a `Menu { ... }` — the sheet/popover state lives on the
/// parent view via a `@State` binding, so multiple items can share or
/// use their own bindings.
struct MenuPresentingButton<Label: View, Content: View>: View {
    let isPresented: Binding<Bool>
    let detents: Set<PresentationDetent>
    let popoverEdge: Edge
    @ViewBuilder let label: () -> Label
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button {
            // Menu dismisses first; presentation state is set so the
            // parent's `.adaptivePresentation` fires after dismissal.
            isPresented.wrappedValue = true
        } label: {
            label()
        }
    }
}
