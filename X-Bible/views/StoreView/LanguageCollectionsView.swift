//
//  LanguageCollectionsView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 10/31/26.
//


//
//  LanguageCollectionsView.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct LanguageCollectionsView: View {
    let language: AudioLanguage
    @State private var collections: [AudioCollection] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if collections.isEmpty {
                ContentUnavailableView(
                    "No Collections",
                    systemImage: "rectangle.stack",
                    description: Text("This language has no collections yet.")
                )
            } else {
                List(collections, id: \.id) { collection in
                    NavigationLink(value: StoreRoute.collection(collection)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name).font(.headline)
                            if let desc = collection.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption).lineLimit(2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(language.name)
        .task { await load() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func load() async {
        guard collections.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let service = StoreApiService()
            collections = try service.fetchCollectionsByLanguage(
                code: language.code, first: 100, skip: 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
