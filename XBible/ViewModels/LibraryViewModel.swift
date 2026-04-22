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
    
    var organizedModules: [String: [String: [XbibleEngine.SwordModule]]] {
        let byCategory = Dictionary(grouping: installedModules, by: { $0.category })
        return byCategory.mapValues { modules in
            Dictionary(grouping: modules, by: { $0.language })
        }
    }
    
    func loadInstalledModules(wrapper: SwordEngineWrapper, category: SidebarItem? = nil) {
        guard let engine = wrapper.engine else { return }
        
        isLoading = true
        
        // Load installed modules on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let allModules = engine.getAvailableModules()
            var installed = allModules.filter { engine.isModuleInstalled(moduleName: $0.name) }
            
            // Filter by category if specified
            if let category = category, category != .all {
                installed = installed.filter { $0.category == category.title }
            }
            
            DispatchQueue.main.async {
                self?.installedModules = installed
                self?.isLoading = false
            }
        }
    }
    
    func refreshModules(wrapper: SwordEngineWrapper, category: SidebarItem? = nil) {
        loadInstalledModules(wrapper: wrapper, category: category)
    }
}