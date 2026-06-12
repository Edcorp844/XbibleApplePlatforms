//
//  TimelineViewModel.swift
//  XBible
//

import SwiftUI
import Combine

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var sections: [TimelineSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func loadEvents() async {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // 1. Locate the file
        guard let url = Bundle.main.url(forResource: "events", withExtension: "txt") else {
            self.errorMessage = "Missing events.txt in app bundle."
            self.isLoading = false
            return
        }
        
        // 2. Perform decoding off the main thread
        // We use Task.detached or simply perform the work before updating @Published vars
        do {
            let data = try Data(contentsOf: url)
            
            // Move heavy decoding work to a background thread
            let decodedSections = try await Task.detached(priority: .userInitiated) {
                let decoder = JSONDecoder()
                return try decoder.decode([TimelineSection].self, from: data)
            }.value

            // 3. Update UI on the MainActor
            self.sections = decodedSections
        } catch {
            self.errorMessage = "Decoding Error: \(error.localizedDescription)"
            print("Full error details: \(error)")
        }
        
        self.isLoading = false
    }
}
