//
//  LibraryCatalogView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/30/26.
//

import SwiftUI

import XbibleEngine

struct LibraryCatalogView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: AudioBibleViewModel
    
    var body: some View {
        NavigationStack {
            List(viewModel.availableModules, id: \.fileName) { module in
                Button(action: {
                    viewModel.selectModule(module)
                    dismiss()
                }) {
                    HStack(spacing: 14) {
                        Image(systemName: "music.note.list")
                            .font(.title2)
                            .foregroundColor(viewModel.selectedModule?.fileName == module.fileName ? .accentColor : .secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(module.metadata?.displayTitle ?? module.fileName)
                                .font(.body)
                                .fontWeight(.medium)
                            if let meta = module.metadata {
                                Text("\(meta.language) • \(meta.contributor)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.selectedModule?.fileName == module.fileName {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Audio Catalog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 450)
    }
}
