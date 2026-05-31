//  DetailView.swift
//  XBible
//
import SwiftUI
import XbibleEngine

struct DetailView: View {
    let selection: SidebarItem?
    
    // 🌟 REFACTORED: Received down directly from the parent ContentView hierarchy
    @ObservedObject var viewModel: AudioBibleViewModel
    
    var body: some View {
        Group {
            switch selection {
            case .study:            StudyView()
            case .store:            StoreView()
            case .all:              LibraryView(category: .all)
            case .bible:            LibraryView(category: .bible)
            case .commentary:       LibraryView(category: .commentary)
            case .dictionary:       LibraryView(category: .dictionary)
            case .lexicons:         LibraryView(category: .lexicons)
            case .dailyDevotional:  LibraryView(category: .dailyDevotional)
            case .essays:           LibraryView(category: .essays)
            case .generalBooks:     LibraryView(category: .generalBooks)
            case .unorthodox:       LibraryView(category: .unorthodox)
            case .bibleTimeline:    BibleTimelineView()
                
            case .audioBible:
                AudioBibleView(viewModel: viewModel)
                
            case .maps:             MapsView()
            case .glossary:         LibraryView(category: .glossary)
            default:
                ContentUnavailableView("Feature Coming Soon", systemImage: "hammer")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            if viewModel.selectedModule != nil && selection != .audioBible {
                Color.clear.frame(height: 76)
            }
        }
    }
}

// MARK: - Placeholder Views for Future Features

struct MapsView: View {
    var body: some View {
        ContentUnavailableView("Bible Maps", systemImage: "map", description: Text("Interactive maps feature coming soon"))
    }
}
