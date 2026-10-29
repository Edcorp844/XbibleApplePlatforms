//
//  X_BibleApp.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/10/26.
//

import SwiftUI
import SwiftData
import XbibleEngine

#if os(macOS)
import AppKit

/// macOS-only: disables AppKit's automatic window tabbing so the
/// "Show Tab Bar" / "Show All Tabs" items disappear from the View menu.
/// iOS has no equivalent, so this whole block is compiled out on iOS.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
#endif

@main
struct X_BibleApp: App {
    @StateObject private var engineWrapper = SwordEngineWrapper()

    /// Created once here and shared through the environment so every
    /// sub-view sees the same instance. Do not also declare a
    /// `@StateObject` for this in `StudyView` — that would create a
    /// second instance and cause state drift.
    @StateObject private var studyViewModel = StudyViewModel()
    @StateObject private var storeViewModel = StoreViewModel()

    @Environment(\.openWindow) private var openWindow

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StudyPageState.self,
            PendingInstallation.self,
            TextConfig.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("❌ ModelContainer error: \(error)")
            print("   localizedDescription: \(error.localizedDescription)")
            if let swiftDataError = error as? SwiftDataError {
                print("   SwiftDataError: \(swiftDataError)")
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if engineWrapper.isReady {
                ContentView()
                    .environmentObject(engineWrapper)
                    .environmentObject(studyViewModel)
                    .environmentObject(storeViewModel)
            } else if let error = engineWrapper.errorMessage {
                Text(error).foregroundColor(.red)
            } else {
                ProgressView("Initializing XBible Engine...")
            }
        }
        .environmentObject(engineWrapper)
        .environmentObject(studyViewModel)
        .environmentObject(storeViewModel)
        .modelContainer(sharedModelContainer)
    }
}
