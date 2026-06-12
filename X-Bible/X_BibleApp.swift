//
//  X_BibleApp.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/10/26.
//

import SwiftUI
import SwiftData
import XbibleEngine

@main
struct X_BibleApp: App {
        @StateObject private var engineWrapper = SwordEngineWrapper()
        @Environment(\.openWindow) private var openWindow
    
        var sharedModelContainer: ModelContainer = {
            let schema = Schema([
                StudyPageState.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
    
    var body: some Scene {
        WindowGroup {
            if engineWrapper.isReady {
                ContentView()
                    .environmentObject(engineWrapper)
            } else if let error = engineWrapper.errorMessage {
                Text(error).foregroundColor(.red)
            } else {
                ProgressView("Initializing XBible Engine...")
            }
        }
        .environmentObject(engineWrapper)
        .modelContainer(for: StudyPageState.self)
        .modelContainer(for: PendingInstallation.self)
    }
}



struct MobileContentView: View {
    var body: some View {
            TabView {
            Text("Home")
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                Text("Ho2")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
        }
    }
}
