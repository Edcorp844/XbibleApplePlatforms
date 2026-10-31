//
//  AlbumModulesView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 10/31/26.
//


//
//  AlbumModulesView.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct AlbumModulesView: View {
    let album: AudioAlbum
    @State private var fullAlbum: AudioAlbum? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let fullAlbum, !fullAlbum.modules.isEmpty {
                List(fullAlbum.modules, id: \.uniqueId) { module in
                    NavigationLink(value: StoreRoute.module(module)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(module.displayTitle).font(.headline)
                            if let c = module.contributor {
                                Text(c).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Modules",
                    systemImage: "waveform",
                    description: Text("This album has no modules yet.")
                )
            }
        }
        .navigationTitle(album.title)
        .task { await load() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func load() async {
        guard fullAlbum == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let service = StoreApiService()
            fullAlbum = try service.fetchAlbum(id: album.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
