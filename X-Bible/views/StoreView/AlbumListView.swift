//
//  AlbumListView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 10/31/26.
//


//
//  AlbumListView.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct AlbumListView: View {
    let collection: AudioCollection
    @State private var albums: [AudioAlbum] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if albums.isEmpty {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "square.stack.3d.up",
                    description: Text("This collection has no albums yet.")
                )
            } else {
                List(albums, id: \.id) { album in
                    NavigationLink(value: StoreRoute.album(album)) {
                        HStack(spacing: 12) {
                            ZStack {
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary)
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title).font(.headline)
                                Text("Order \(album.order)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(collection.name)
        .task { await load() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func load() async {
        guard albums.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let service = StoreApiService()
            albums = try service.fetchAlbumsByCollection(
                collectionId: collection.id, first: 100, skip: 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
