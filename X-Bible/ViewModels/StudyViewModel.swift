//
//  StudyViewModel.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftUI
import XbibleEngine
import SwiftData
import Foundation
import Combine

// MARK: - Study View Model
@MainActor
final class StudyViewModel: ObservableObject {
    @Published var tabs: [TabInstance] = []
    @Published var selectedTabId: UUID?
    
    @Published var availableModules: [XbibleEngine.SwordModule] = []
    @Published var availableBooks: [XbibleEngine.ModuleBook] = []
    @Published var availableLexicons: [XbibleEngine.SwordModule] = []
    @Published var availableCommentaries: [XbibleEngine.SwordModule] = []
    
    var activeTabIndex: Int? {
        guard let id = selectedTabId else { return nil }
        return tabs.firstIndex(where: { $0.id == id })
    }
}
