//
//  TimelineViewModel.swift
//  XBible
//

import SwiftUI
import Combine
import XbibleEngine

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var periods : [Period] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    func loadEvents() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        let timeline = TimelineData()
        let data = timeline.getData()
        
        self.periods = data
        
        
        self.isLoading = false
    }
}
