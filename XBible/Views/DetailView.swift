//
//  DetailView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//
import SwiftUI
import XbibleEngine

struct DetailView: View {
    let selection: SidebarItem?
    
    var body: some View {
        // 1. Switch to a ZStack aligned to the bottom to allow layering
        ZStack(alignment: .bottom) {
            
            // The active content view now occupies 100% of the window area
            Group {
                switch selection {
                case .study:
                    StudyView()
                case .store:
                    StoreView()
                case .all:
                    LibraryView(category: .all)
                case .bible:
                    LibraryView(category: .bible)
                case .commentary:
                    LibraryView(category: .commentary)
                case .dictionary:
                    LibraryView(category: .dictionary)
                case .lexicons:
                    LibraryView(category: .lexicons)
                case .dailyDevotional:
                    LibraryView(category: .dailyDevotional)
                case .essays:
                    LibraryView(category: .essays)
                case .generalBooks:
                    LibraryView(category: .generalBooks)
                case .unorthodox:
                    LibraryView(category: .unorthodox)
                case .bibleTimeline:
                    BibleTimelineView()
                case .audioBible:
                    
                    let sandboxEngine = AudioEngine()
                        
                        AudioBibleView(engine: sandboxEngine)
                    
                case .maps:
                    MapsView()
                case .glossary:
                    LibraryView(category: .glossary)
                default:
                    ContentUnavailableView("Feature Coming Soon", systemImage: "hammer")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // CRITICAL: Tells SwiftUI to let your list/text flow completely behind
            // the bottom window frame/player area instead of cutting off early.
            .ignoresSafeArea(.container, edges: .bottom)
            
            // 2. The floating player bar
//            PersistentAudioPlayerBar()
//                // Gives it that pill/card floating appearance away from the window frame edges
//                .padding(.horizontal, 24)
//                .padding(.bottom, 20)
        }
    }
}

// MARK: - Placeholder Views for Future Features

struct MapsView: View {
    var body: some View {
        ContentUnavailableView("Bible Maps", systemImage: "map", description: Text("Interactive maps feature coming soon"))
    }
}
