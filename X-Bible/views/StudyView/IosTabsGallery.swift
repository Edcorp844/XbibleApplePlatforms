//
//  IosTabsGallery.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//
import SwiftUI
import XbibleEngine

// MARK: - iOS Tabs Gallery

#if os(iOS)
struct TabsGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tabs: [TabInstance]
    @Binding var selectedTabId: UUID?
    
    var createNewTabAction: () -> Void
    var closeTabAction: (UUID) -> Void
    var onSelect: () -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(tabs) { tab in
                        TabCardView(
                            tab: tab,
                            isSelected: selectedTabId == tab.id,
                            onClose: { closeTabAction(tab.id) }
                        )
                        .onTapGesture {
                            selectedTabId = tab.id
                            onSelect()
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Spacer()
                        Button(action: createNewTabAction) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct TabCardView: View {
    let tab: TabInstance
    let isSelected: Bool
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tab.selectedModule.isEmpty ? "—" : tab.selectedModule)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Text(tab.selectedBook.isEmpty
                 ? "Empty Tab"
                 : "\(tab.selectedBook) \(tab.selectedChapter)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(previewText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(height: 140)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
        )
        .contentShape(Rectangle())
    }
    
    private var previewText: String {
        guard let firstSection = tab.sections.first,
              let firstVerse = firstSection.verses.first,
              !firstVerse.words.isEmpty else {
            return "Empty content layout"
        }
        return firstVerse.words.map { $0.text }.joined(separator: " ")
    }
}
#endif



