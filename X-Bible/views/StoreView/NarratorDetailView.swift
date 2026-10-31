//
//  NarratorDetailView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 10/31/26.
//


//
//  NarratorDetailView.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

struct NarratorDetailView: View {
    let narrator: AudioContributor
    @ObservedObject var viewModel: AudioStoreViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    avatar
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.separator, lineWidth: 0.5))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(narrator.name).font(.title2.bold())
                        Label("Narrator", systemImage: "person.wave.2")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }

                if let bio = narrator.bio?.text, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Biography").font(.headline)
                        Text(bio).font(.body).textSelection(.enabled)
                    }
                }

                let narrated = viewModel.availableModules.filter {
                    $0.contributor?.caseInsensitiveCompare(narrator.name) == .orderedSame
                }
                if !narrated.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Titles (\(narrated.count))").font(.headline)
                        ForEach(narrated, id: \.uniqueId) { m in
                            Text("• \(m.displayTitle)").font(.callout)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle(narrator.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = narrator.photo?.url,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .empty:
                    ProgressView()
                case .failure:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Text(initials(narrator.name))
                .font(.title.bold()).foregroundStyle(.secondary)
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #else
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #endif
    }
}
