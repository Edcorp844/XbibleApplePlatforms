//
//  LibraryViewModel.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/22/26.
//

import SwiftUI
import XbibleEngine
import Combine

class LibraryViewModel: ObservableObject {
    @Published var installedModules: [XbibleEngine.SwordModule] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var modulesByLanguage: [String: [XbibleEngine.SwordModule]] {
        Dictionary(grouping: installedModules, by: { $0.language })
    }
    
    func loadInstalledModules(wrapper: SwordEngineWrapper, category: SidebarItem? = nil) {
        guard let engine = wrapper.engine else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        wrapper.engineQueue.async { [weak self] in
            guard let engine = wrapper.engine else { return }
            let loadedModules: [XbibleEngine.SwordModule]
            
            switch category {
            case .bible:
                loadedModules = engine.getBibleModules()
            case .dictionary:
                loadedModules = engine.getDictionaryModules()
            case .commentary:
                loadedModules = engine.getCommentaryModules()
            case .lexicons:
                loadedModules = engine.getLexiconModules()
            case .glossary:
                loadedModules = engine.getGlossaryModules()
            case .generalBooks:
                loadedModules = engine.getBookModules()
            case .dailyDevotional:
                loadedModules = engine.getDailyDevotionalModules()
            case .essays:
                loadedModules = engine.getEssayModules()
            case .unorthodox:
                loadedModules = engine.getAvailableModules().filter { 
                    engine.isModuleInstalled(moduleName: $0.name) && 
                    ($0.category.lowercased().contains("unorthodox") || $0.category.lowercased().contains("cult"))
                }
            default:
                loadedModules = engine.getAvailableModules().filter { engine.isModuleInstalled(moduleName: $0.name) }
            }
            
            DispatchQueue.main.async {
                self?.installedModules = loadedModules
                self?.isLoading = false
            }
        }
    }
    
    func refreshModules(wrapper: SwordEngineWrapper, category: SidebarItem? = nil) {
        loadInstalledModules(wrapper: wrapper, category: category)
    }
}
