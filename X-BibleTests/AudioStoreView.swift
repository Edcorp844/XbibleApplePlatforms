//
//   AudioStoreView.swift
//   X-Bible
//
//   Created by Zoe Brooklyn on 6/10/26.
//

import SwiftUI
import XbibleEngine

struct AudioStoreView: View {
    @StateObject private var viewModel = AudioStoreViewModel()
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
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
                    description: Text("Check your internet connection or reload the catalog.")
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
                }
            }
        }
        .navigationTitle("Audio Store")
        .padding()
        // 🚀 OPTIMIZATION: Conditional platform evaluation wrapper safely guarding iOS styling properties
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            await viewModel.loadCatalog()
        }
        .task {
            await viewModel.loadCatalog()
        }
        // 🚀 OPTIMIZATION: Explicit desktop layout toolstrip for direct reload action
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task { await viewModel.loadCatalog() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload store inventory catalog")
            }
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                ErrorBannerView(message: error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.errorMessage)
    }
    
    // --- CROSS-PLATFORM SYSTEM COLOR RESOLVER ---
    private var storeBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemGroupedBackground)
        #endif
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
