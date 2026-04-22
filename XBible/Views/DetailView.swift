//
//  DetailView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI

struct DetailView: View {
    let selection: SidebarItem?
    
    var body: some View {
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
            TimelineView()
        case .audioBible:
            AudioBibleView()
        case .maps:
            MapsView()
        case .glossary:
            LibraryView(category: .glossary)
        default:
            ContentUnavailableView("Feature Coming Soon", systemImage: "hammer")
        }
    }
}

// MARK: - Placeholder Views for Future Features

struct TimelineView: View {
    var body: some View {
        ContentUnavailableView("Bible Timeline", systemImage: "calendar.day.timeline.left", description: Text("Interactive timeline feature coming soon"))
    }
}

struct AudioBibleView: View {
    var body: some View {
        ContentUnavailableView("Audio Bible", systemImage: "speaker.wave.2", description: Text("Audio bible feature coming soon"))
    }
}

struct MapsView: View {
    var body: some View {
        ContentUnavailableView("Bible Maps", systemImage: "map", description: Text("Interactive maps feature coming soon"))
    }
}
