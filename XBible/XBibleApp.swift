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
        // Main Application View Workspace
        WindowGroup {
            Group {
                if engineWrapper.isReady {
                    ContentView()
                        .environmentObject(engineWrapper)
                } else if let error = engineWrapper.errorMessage {
                    Text(error).foregroundColor(.red)
                } else {
                    ProgressView("Initializing Sword Engine...")
                }
            }
        }
        .environmentObject(engineWrapper)
        .modelContainer(for: StudyPageState.self)
        .modelContainer(for: PendingInstallation.self)
        
        // --- NATIVE SYSTEM APP MENU COMMANDS ---
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About XBible") {
                    openWindow(id: "about-window")
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }

        // --- FIXED-SIZE STANDALONE ABOUT WINDOW SCENE ---
        Window("About XBible", id: "about-window") {
            AboutAppWindowView()
        }
        .windowStyle(.hiddenTitleBar) // Keeps window controls but delivers a clean modern look
        .windowResizability(.contentSize) // Forces window to adapt to the View frame and strips resize handles
    }
}

// MARK: - Dedicated Window Content

struct AboutAppWindowView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            
            // --- LEFT COLUMN: APP ICON ---
            VStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                Spacer()
            }
            
            // --- RIGHT COLUMN: BRANDING & METADATA ---
            VStack(alignment: .leading, spacing: 0) {
                
                // Header Group
                Text("XBible")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Version 1.0.0 (Build 2026)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                // Pitch/Description Paragraph
                Text("A high-performance scripture study suite powered by the crosswire SWORD engine and native Swift architecture. Built for deep textual analysis and split-pane structural reading workflows.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true) // Prevents ellipsis truncation
                                    .padding(.top, 12)
                
                // Acknowledgments Block
                VStack(alignment: .leading, spacing: 4) {
                    Text("Credits & Open Source:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("• Crosswire SWORD Project Engine (GPLv2)")
                    Text("• XBible Engine")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.top, 14)
                
                Spacer(minLength: 16)
                
                // --- FOOTER: LEGAL COPYRIGHTS ---
                VStack(alignment: .leading, spacing: 2) {
                    Text("Copyright © 2026 Frost Edson. All rights reserved.")
                    Text("Licensed under the MIT License. Terms apply.")
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        // Expanded layout boundaries slightly to cleanly fit the corporate details side-by-side
        .frame(width: 420, height: 230)
    }
}
