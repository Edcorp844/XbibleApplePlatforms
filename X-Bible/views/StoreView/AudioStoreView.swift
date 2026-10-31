//
//  StoreView 2.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 10/31/26.
//


//
//  StoreView.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct AudioStoreView: View {
    @StateObject private var viewModel = AudioStoreViewModel()
    @State private var path: [StoreRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            StoreHomeView(viewModel: viewModel, path: $path)
                .navigationDestination(for: StoreRoute.self) { route in
                    routeDestination(route)
                }
        }
        .task {
            if viewModel.availableModules.isEmpty {
                await viewModel.bootstrap()
                await viewModel.loadNarrators()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Route table

    @ViewBuilder
    private func routeDestination(_ route: StoreRoute) -> some View {
        switch route {
        case .language(let language):
            LanguageCollectionsView(language: language)
        case .collection(let collection):
            AlbumListView(collection: collection)
        case .album(let album):
            AlbumModulesView(album: album)
        case .narrator(let narrator):
            NarratorDetailView(narrator: narrator, viewModel: viewModel)
        case .module(let module):
            ModuleDetailView(module: module, viewModel: viewModel)
        }
    }
}

/// Type-safe routes for the store's navigation stack.
/// Using an enum instead of raw model values avoids `Hashable`/`Identifiable`
/// problems with uniffi-generated types.
enum StoreRoute: Hashable {
    case language(AudioLanguage)
    case collection(AudioCollection)
    case album(AudioAlbum)
    case narrator(AudioContributor)
    case module(RemoteAudioModuleInfo)
}
