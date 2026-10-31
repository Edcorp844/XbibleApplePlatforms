//
//  CollectionsGroup.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine
import Foundation


struct CollectionsGroup: View {
    let collections: [AudioCollection]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Text("Collections")
                        .font(.title3.bold())
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(collections, id: \.id) { collection in
                        CollectionTile(collection: collection)
                    }
                }
                .padding(.horizontal) // Padding for scroll edges
                .scrollTargetLayout() // iOS 17+ for snapping (optional, but feels native)
            }
            // If you are on iOS 17+, add snapping to make it feel like a carousel
            // .scrollTargetBehavior(.viewAligned)
        }
    }
}

// MARK: - Tile

private struct CollectionTile: View {
    let collection: AudioCollection

    // Fixed width keeps the items uniform horizontally
    private let tileWidth: CGFloat = 350

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Square artwork on the left
            CollectionThumbnail(collection: collection)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator, lineWidth: 0.5)
                )

            // Title and metadata on the right
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Group{
                   // Text("\(collection.updatedAt.formattedAPIDate)").foregroundStyle(.secondary)
                    
                    if let description = collection.description {
                        Text(description)
                            .lineLimit(2)
                    } else {
                        Text("Audio Collection")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            // Trailing ellipsis menu
            Menu {
                Button("Play", systemImage: "play.fill") { /* Action */ }
                Button("Download", systemImage: "arrow.down.circle") { /* Action */ }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(12)
        // Optional: Add a subtle background to each tile if you want them to stand out
        // .background(Color(uiColor: .secondarySystemGroupedBackground))
        // .cornerRadius(12)
        .frame(width: tileWidth)
        .contentShape(Rectangle())
    }
}

// MARK: - Thumbnail

private struct CollectionThumbnail: View {
    let collection: AudioCollection

    private var initials: String {
        let parts = collection.name.split(separator: " ", omittingEmptySubsequences: true)
        return String(parts.prefix(2).compactMap { $0.first }).uppercased()
    }

    private var palette: (Color, Color) {
        CollectionPalette.gradient(for: collection.id)
    }

    var body: some View {
        ZStack {
            // The soft gradient background
            LinearGradient(
                colors: [palette.0, palette.1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                
            // If I add artwork to AudioCollection later:
            /*
            if let urlString = collection.artwork?.url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    }
                }
            }
            */
        }
    }
}

// MARK: - Palette (same as before)

enum CollectionPalette {
    private static let pairs: [(Color, Color)] = [
        (Color(red: 0.98, green: 0.87, blue: 0.80), Color(red: 0.96, green: 0.72, blue: 0.65)), // peach
        (Color(red: 0.85, green: 0.92, blue: 0.98), Color(red: 0.68, green: 0.82, blue: 0.94)), // sky
        (Color(red: 0.90, green: 0.96, blue: 0.88), Color(red: 0.72, green: 0.88, blue: 0.72)), // sage
        (Color(red: 0.97, green: 0.88, blue: 0.94), Color(red: 0.92, green: 0.74, blue: 0.85)), // rose
        (Color(red: 0.92, green: 0.90, blue: 0.98), Color(red: 0.79, green: 0.76, blue: 0.94)), // lavender
        (Color(red: 0.99, green: 0.94, blue: 0.82), Color(red: 0.95, green: 0.84, blue: 0.62)), // honey
        (Color(red: 0.86, green: 0.94, blue: 0.95), Color(red: 0.68, green: 0.86, blue: 0.88)), // aqua
        (Color(red: 0.96, green: 0.88, blue: 0.86), Color(red: 0.90, green: 0.72, blue: 0.70)), // clay
        (Color(red: 0.90, green: 0.93, blue: 0.86), Color(red: 0.76, green: 0.84, blue: 0.68)), // moss
        (Color(red: 0.94, green: 0.90, blue: 0.96), Color(red: 0.82, green: 0.76, blue: 0.90)), // lilac
        (Color(red: 0.88, green: 0.91, blue: 0.97), Color(red: 0.72, green: 0.79, blue: 0.92)), // periwinkle
        (Color(red: 0.98, green: 0.91, blue: 0.86), Color(red: 0.94, green: 0.79, blue: 0.72)), // apricot
    ]

    static func gradient(for id: String) -> (Color, Color) {
        pairs[Int(fnv1a(id) % UInt64(pairs.count))]
    }

    private static func fnv1a(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}


extension String {
    /// Converts an ISO8601 string from the backend (e.g., "2026-10-30T13:17:22.610941+00:00")
    /// into a formatted date string like "Oct 30" or "Oct 30, 2026".
    var formattedAPIDate: String {
        // 1. Try parsing with fractional seconds (Hygraph usually includes these)
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // 2. Fallback formatter without fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let date = formatterWithFractional.date(from: self) ?? formatter.date(from: self) else {
            return self // Return raw string if parsing fails
        }
        
        // 3. Format for display
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
