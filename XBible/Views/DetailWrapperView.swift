//
//  DetailWrapperView.swift
//  XBible
//
import SwiftUI
import XbibleEngine

struct DetailWrapperView: View {
    let selection: SidebarItem
    @ObservedObject var audioViewModel: AudioBibleViewModel
    
    // Check if the overlay should float exclusively inside this detail frame boundary
    private var shouldShowFloatingBar: Bool {
        audioViewModel.selectedModule != nil && selection != .audioBible
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // Core main document pane contents
            DetailView(selection: selection, viewModel: audioViewModel)
            
            // The floating bar overlay strictly contained inside the detail pane width limits
            if shouldShowFloatingBar {
                PersistentAudioPlayerBar(viewModel: audioViewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: shouldShowFloatingBar)
    }
}
