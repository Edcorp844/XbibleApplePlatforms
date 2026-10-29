import SwiftUI
import XbibleEngine

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
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
#if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
#endif
#if os(iOS)
            .background(.background)
#endif
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let imageString = event.image,
                       !imageString.isEmpty,
                       let url = URL(string: imageString) {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.1))
                        }
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(TimelineUtils.rangeLabel(start: event.start, end: event.end))
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.secondary)
                        
                        Text(event.title)
                            .font(.title)
                            .bold()
                    }
                    
                    Text("Description for \(event.slug)...")
                        .font(.body)
                        .lineSpacing(4)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scriptures").font(.headline)
                        ForEach(["Genesis 1:1", "Hebrews 11:1"], id: \.self) { ref in
                            Button(ref) {
                                // Jump to reader
                            }
#if os(macOS)
                            .buttonStyle(.link)
#endif
#if os(iOS)
                            .buttonStyle(.plain)
#endif
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 400, maxWidth: 600, minHeight: 400, maxHeight: 700)
    }
}
