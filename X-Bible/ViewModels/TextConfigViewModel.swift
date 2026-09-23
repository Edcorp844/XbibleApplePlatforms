//
//  TextConfigViewModel.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//


import SwiftUI
import SwiftData
import Combine

@MainActor
final class TextConfigViewModel: ObservableObject {
    private var modelContext: ModelContext
    
    @Published var config: TextConfig
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        let descriptor = FetchDescriptor<TextConfig>()
        if let existing = try? modelContext.fetch(descriptor).first {
            self.config = existing
        } else {
            let newConfig = TextConfig()
            modelContext.insert(newConfig)
            try? modelContext.save()
            self.config = newConfig
        }
    }
    
    /// Persists any modification made to the config and notifies observers
    func saveChanges() {
        try? modelContext.save()
        objectWillChange.send()
    }
    
    /// Resets all styling options back to their initial defaults
    public func resetToDefaults() {
        config.fontSize = 18.0
        config.useSystemFont = true
        config.systemDesign = .default
        config.fontFamilyName = ""
        config.fontPostScriptName = ""
        config.lineSpacing = 1.5
        config.wordSpacing = 8.0
        config.justify = false
        config.showRedWords = true
        config.showStrongs = true
        config.showLemma = true
        config.showMorph = true
        config.showVerseNotes = true
        config.showWordNotes = true
        config.addedWordsStyle = .brackets
        
        saveChanges()
    }
}
