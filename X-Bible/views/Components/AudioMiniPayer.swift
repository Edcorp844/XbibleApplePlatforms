#if os(iOS)
import SwiftUI
import XbibleEngine

struct AudioMiniPayer: View {
    // 1. Pass primitive properties directly instead of a state object wrapper
    let displayTitle: String
    let activeLyricTitle: String
    let isPlaying: Bool
    let hasSelectedModule: Bool
    let artworkImage: UIImage?
    
    // 2. Clear callback event closures to handle events without touch interference
    var onTogglePlayback: () -> Void
    var onSkipForward: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                // Artwork Layout
                if let artwork = artworkImage {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                }
                
                // Text Description Layout (Strictly protecting text boundaries)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle).bold()
                    Text(activeLyricTitle)
                }
                .font(.footnote)
                .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            // Layout Controls Group retained exactly as intended
            Group {
                Button(action: {
                    onTogglePlayback()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                
                Button(action: {
                    onSkipForward()
                }) {
                    Image(systemName: "goforward.30")
                }
            }
            .font(.title2)
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
            .disabled(!hasSelectedModule)
        }
        .padding(.horizontal, 15)
    }
}
#endif
