//
//  GeneralBookTabView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/29/26.
//

import SwiftUI

struct GeneralBookTabView : View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject var viewModel: StudyViewModel
    
    // Nav-button auto-hide
    @State private var areNavButtonsVisible = true
    @State private var navAutoHideTask: Task<Void, Never>? = nil
    private let navAutoHideDelay: Duration = .seconds(2)
    
    private var tab: Binding<TabInstance>
    
    init(tab: Binding<TabInstance>) {
        self.tab = tab
    }
    
    
    var body: some View {
        let navigationButtonsAlignment = (horizontalSizeClass == .compact)
            ? HorizontalAlignment.trailing
            : .center

        ZStack {
            ScrollView {
                SectionContentView(
                    sections: tab.wrappedValue.sections,
                    onWordClick: { word in viewModel.lookupWord(word) },
                    onStrongsClicked: { strongs in viewModel.lookupStrongs(strongs) }
                )
                .padding()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in revealNavButtons() }
                    .onEnded   { _ in revealNavButtons() }
            )
            .onTapGesture { revealNavButtons() }

            VStack(alignment: navigationButtonsAlignment) {
                HStack(alignment: .bottom) {
                    NavigationRectButton(
                        icon: "chevron.compact.left",
                        action: viewModel.goToPreviousChapter,
                        isDisabled: !viewModel.canGoToPrevious(),
                        isSide: true
                    )
                    Spacer()
                    NavigationRectButton(
                        icon: "chevron.compact.right",
                        action: viewModel.goToNextChapter,
                        isDisabled: !viewModel.canGoToNext(),
                        isSide: true
                    )
                }
                .padding()
            }
            .opacity(areNavButtonsVisible ? 1 : 0)
            .allowsHitTesting(areNavButtonsVisible)
            .animation(.easeInOut(duration: 0.25), value: areNavButtonsVisible)
        }    }
    
    private func revealNavButtons() {
        navAutoHideTask?.cancel()

        if !areNavButtonsVisible { areNavButtonsVisible = true }

        navAutoHideTask = Task { @MainActor in
            try? await Task.sleep(for: navAutoHideDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                areNavButtonsVisible = false
            }
        }
    }
}
