//
//  AudioStoreView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/10/26.
//

import SwiftUI
import XbibleEngine

struct AudioStoreView: View {
    @StateObject private var viewModel = AudioStoreViewModel()
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        // 🛑 REMOVED: NavigationStack {
        Group {
            if viewModel.isLoading && viewModel.availableModules.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading audio modules...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.availableModules.isEmpty {
                ContentUnavailableView(
                    "No Modules Available",
                    systemImage: "waveform.badge.exclamationmark",
                    description: Text("Check your internet connection or pull down to retry.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(viewModel.availableModules, id: \.uniqueId) { module in
                            RemoteAudioModuleView(module: module) {
                                viewModel.installModule(id: module.uniqueId)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.bottom))
            }
        }
        .navigationTitle("Audio Store")
        // Keep your bar items configuration flat on the inner content view
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadCatalog()
        }
        .task {
            await viewModel.loadCatalog()
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                ErrorBannerView(message: error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.errorMessage)
        // 🛑 REMOVED: }
    }
}
// ─── COMPONENT: ERROR FLOATING BANNER ───

struct ErrorBannerView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding()
        .background(Capsule().fill(Color.red))
        .shadow(radius: 6, y: 3)
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
}
