//
//  XBibleApp.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/20/26.
//

//import SwiftUI
//import SwiftData
//
//@main
//struct XBibleApp: App {
//    @StateObject private var engineWrapper = SwordEngineWrapper()
//    @Environment(\.openWindow) private var openWindow
//    
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            StudyPageState.self,
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()
//
//    var body: some Scene {
//        // Main Application View Workspace
//        WindowGroup {
//            Group {
//                if engineWrapper.isReady {
//                    ContentView()
//                        .environmentObject(engineWrapper)
//                        // ─── THE TABVIEW FIX ───
//                        // Applies adaptive sidebar layout strictly to macOS/iPadOS context ecosystems
//                        #if os(macOS)
//                        .tabViewStyle(.sidebarAdaptable)
//                        #else
//                        .tabViewStyle(.automatic) // Forces natural bottom TabBar on iOS phones
//                        #endif
//                } else if let error = engineWrapper.errorMessage {
//                    Text(error).foregroundColor(.red)
//                } else {
//                    ProgressView("Initializing Sword Engine...")
//                }
//            }
//        }
//        .environmentObject(engineWrapper)
//        .modelContainer(for: StudyPageState.self)
//        .modelContainer(for: PendingInstallation.self)
//        
//        // --- NATIVE SYSTEM APP MENU COMMANDS & EXTRA WINDOWS (macOS ONLY) ---
//        #if os(macOS)
//        .commands {
//            CommandGroup(replacing: .appInfo) {
//                Button("About XBible") {
//                    openWindow(id: "about-window")
//                }
//                .keyboardShortcut("i", modifiers: [.command, .shift])
//            }
//        }
//        #endif
//
//        // --- FIXED-SIZE STANDALONE ABOUT WINDOW SCENE ---
//        #if os(macOS)
//        Window("About XBible", id: "about-window") {
//            AboutAppWindowView()
//        }
//        .windowStyle(.hiddenTitleBar)
//        .windowResizability(.contentSize)
//        #endif
//    }
//}
//
import SwiftUI

@main
struct XBibleApp: App {
    var body: some Scene {
        // Main Application View Workspace
        WindowGroup {
            Group {
                HStack{
                    Text("Heeloworld")
                }
            }
        }
    }
}
