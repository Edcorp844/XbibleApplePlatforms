//
//  XBibleApp.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/20/26.
//

import SwiftUI
import SwiftData

@main
struct XBibleApp: App {
    @StateObject private var engineWrapper = SwordEngineWrapper()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(
            StudyPageState.self,
        )
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
                ProgressView("Initializing Sword Engine...")
            }
        }
        .environmentObject(engineWrapper)
        .modelContainer(for: StudyPageState.self)
        .modelContainer(for: PendingInstallation.self)
        
    }
}
