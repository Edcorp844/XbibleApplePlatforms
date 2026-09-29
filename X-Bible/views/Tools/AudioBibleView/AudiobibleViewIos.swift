//
//  AudiobibleViewIos.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/17/26.
//

import SwiftUI
import XbibleEngine

#if os(iOS)
struct AudiobibleViewIos: View {
    @State private var selectedLanguageFilter: String? = nil
    @State private var selectedContributorFilter: String? = nil
    @State private var sortBySetting: SortOption = .title
    @State private var showLibrarySheet = false
    @State private var searchText = "" 
    @ObservedObject var viewModel: AudioBibleViewModel
    
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case date = "Date"
        case contributor = "Contributor"
        case title = "Title"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    
                    ForEach(processedModules, id: \.fileName) { module in
                        HStack(spacing: 14) {
                            
                            // 1. CLICKABLE INTERACTIVE ZONE (Safely separated from menu)
                            HStack(spacing: 14) {
                                Group {
                                    if let data = module.artwork.imageBytes(), let compiledImage = UIImage(data: data) {
                                        Image(uiImage: compiledImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(6)
                                            .clipped()
                                    } else {
                                        FallbackBadge(module: module)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(module.metadata?.displayTitle ?? "Unknown Title")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    Text(module.metadata?.description ?? "No description available")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    Text(module.metadata?.language ?? "Unknown Language")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .contentShape(Rectangle()) // Ensures padding blanks accept taps
                            .onTapGesture {
                                viewModel.selectModule(module)
                            }
                            
                            Spacer()
                            
                            // 2. DECOUPLED OPTIONS CONTEXT MENU SIBLING
                            Menu {
                                Button(role: .destructive) {
                                    // Handle context deletion using module.fileName
                                } label: {
                                    Label("Remove Module", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 12)  // Generates comfortable touch targets
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain) // Sanitizes iOS focus engine highlight tracking
                        }
                        
                        VStack(spacing: 0) {
                            Divider()
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Audio Bible")
            // Native search modifier applied to the Navigation hierarchy context
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search audiobooks...")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    
                    // 🔍 FILTER MENU: Uses explicit metadata rules
                    Menu {
                        Menu("Language") {
                            Button("All Languages", action: { selectedLanguageFilter = nil })
                            ForEach(Array(Set(viewModel.availableModules.compactMap { $0.metadata?.language })), id: \.self) { lang in
                                Button(lang, action: { selectedLanguageFilter = lang })
                            }
                        }
                        
                        Menu("Contributor") {
                            Button("All Contributors", action: { selectedContributorFilter = nil })
                            ForEach(Array(Set(viewModel.availableModules.compactMap { $0.metadata?.contributor })), id: \.self) { contributor in
                                Button(contributor, action: { selectedContributorFilter = contributor })
                            }
                        }
                        
                        if selectedLanguageFilter != nil || selectedContributorFilter != nil {
                            Divider()
                            Button(role: .destructive, action: {
                                selectedLanguageFilter = nil
                                selectedContributorFilter = nil
                            }) {
                                Label("Clear Filters", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: (selectedLanguageFilter != nil || selectedContributorFilter != nil) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }

                    // 🔀 SORT MENU: Maps choices directly to properties
                    Menu {
                        Picker("Sort By", selection: $sortBySetting) {
                            ForEach(SortOption.allCases) { option in
                                Label(option.rawValue, systemImage: sortIcon(for: option))
                                    .tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
    }

    // ------------------- COMPUTED VIEW LOGIC CHANNELS -------------------

    private var processedModules: [AudioModuleInfo] {
        var modules = viewModel.availableModules
        
        // 1. Process Text Search
        if !searchText.isEmpty {
            modules = modules.filter { module in
                let title = module.metadata?.displayTitle ?? ""
                let description = module.metadata?.description ?? ""
                let contributor = module.metadata?.contributor ?? ""
                
                return title.localizedCaseInsensitiveContains(searchText) ||
                       description.localizedCaseInsensitiveContains(searchText) ||
                       contributor.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 2. Process Filters safely using underlying metadata tokens
        if let language = selectedLanguageFilter {
            modules = modules.filter { $0.metadata?.language == language }
        }
        if let contributor = selectedContributorFilter {
            modules = modules.filter { $0.metadata?.contributor == contributor }
        }
        
        // 3. Process Sorting Rules targeting structural properties
        switch sortBySetting {
        case .title:
            modules.sort { ($0.metadata?.displayTitle ?? "") < ($1.metadata?.displayTitle ?? "") }
        case .contributor:
            modules.sort { ($0.metadata?.contributor ?? "") < ($1.metadata?.contributor ?? "") }
        case .date:
            // Sorts descending using the Int32 version property mapping
            modules.sort { ($0.metadata?.version ?? 0) > ($1.metadata?.version ?? 0) }
        }
        
        return modules
    }

    private func sortIcon(for option: SortOption) -> String {
        switch option {
        case .title: return "textformat"
        case .contributor: return "person.crop.circle"
        case .date: return "calendar"
        }
    }
    
    @ViewBuilder
    private var artworkView: some View {
        if let uiImage = viewModel.decodedArtwork {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackArtworkBackground
        }
    }
    
    private var fallbackArtworkBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(
                colors: [.purple.opacity(0.3), .indigo.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .aspectRatio(contentMode: .fit)
            .overlay(
                Image(systemName: "headphones")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.6))
            )
    }
}
#endif
