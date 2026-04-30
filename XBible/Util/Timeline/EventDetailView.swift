//
//  EventDetailView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/30/26.
//

import SwiftUI

struct EventDetailView: View {
    let event: TimelineEvent
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // macOS Header Style
            HStack {
                Text(event.title)
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Image
                    if let image = event.image {
                        AsyncImage(url: URL(string: image)) { img in
                            img.resizable()
                               .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.1))
                        }
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(TimelineUtils.calculateLabel(start: event.start, end: event.end))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        Text(event.title)
                            .font(.title)
                            .bold()
                    }

                    Text("Description for \(event.slug)...")
                        .font(.body)
                        .lineSpacing(4)

                    // Related Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scriptures")
                            .font(.headline)
                        
                        ForEach(["Genesis 1:1", "Hebrews 11:1"], id: \.self) { ref in
                            Button(ref) {
                                // Jump to reader logic
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
                .padding()
            }
        }
        // Set a reasonable size for macOS sheets
        .frame(minWidth: 400, maxWidth: 600, minHeight: 400, maxHeight: 700)
    }
}
