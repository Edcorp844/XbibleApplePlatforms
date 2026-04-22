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
    }
}
