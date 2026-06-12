////
////  TouchbarExtension.swift
////  XBible
////
////  Created by Zoe Brooklyn on 5/25/26.
////
//import SwiftUI
//
//// MARK: - Touch Bar Extension
//extension StudyView {
//    @ViewBuilder
//    var bibleStudyTouchBar: some View {
//        // 1. Previous Chapter Navigation
//        Button(action: {
//            goToPreviousChapter()
//        }) {
//            Image(systemName: "chevron.left")
//                .font(.system(size: 14, weight: .bold))
//                .frame(minWidth: 44, maxHeight: .infinity)
//        }
//        .buttonStyle(.bordered)
//        .cornerRadius(8)
//        .disabled(!canGoToPrevious())
//
//        // 2. Next Chapter Navigation
//        Button(action: {
//            goToNextChapter()
//        }) {
//            Image(systemName: "chevron.right")
//                .font(.system(size: 14, weight: .bold))
//                .frame(minWidth: 44, maxHeight: .infinity)
//        }
//        .buttonStyle(.bordered)
//        .cornerRadius(8)
//        .disabled(!canGoToNext())
//
//        Spacer()
//
//        // 3. Main Tools: Search Button
//        Button(action: {
//            print("Search triggered via Touch Bar")
//        }) {
//            Label("Search", systemImage: "magnifyingglass")
//                .padding(.horizontal, 8)
//                .frame(maxHeight: .infinity)
//        }
//        .buttonStyle(.bordered)
//        .cornerRadius(8)
//
//        // 4. Study Tools Toggle Link
//        Button(action: {
//            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
//                isSplitViewPresented.toggle()
//            }
//        }) {
//            Label(
//                isSplitViewPresented ? "Close Study Tools" : "Open Study Tools",
//                systemImage: "sidebar.right"
//            )
//            .padding(.horizontal, 8)
//            .frame(maxHeight: .infinity)
//        }
//        .buttonStyle(.bordered)
//        .cornerRadius(8)
//    }
//}
